/**
 * Worktree-isolated subagent extension for pi-mono.
 *
 * Each subagent spawns in its own git worktree (a throwaway copy of the repo
 * at HEAD + the parent's dirty state). After the subagent finishes, a delta
 * patch is extracted containing only the subagent's changes. Patches are
 * either auto-applied to the real working tree or surfaced for manual review
 * when they conflict.
 *
 * The parent agent controls each subagent's role, model, and tools inline.
 * Named agent presets from ~/.pi/agent/agents/*.md are optional — if no
 * agent name is given, a default config is used and the parent specifies
 * everything via the task description and per-task overrides.
 *
 * Modes:
 *   - single:   { task, agent?, model?, tools?, systemPrompt?, isolated? }
 *   - parallel:  { tasks: [...], isolated? }
 *   - chain:     { chain: [...], isolated? }
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { StringEnum } from "@mariozechner/pi-ai";
import { type ExtensionAPI, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { type AgentConfig, type AgentScope, discoverAgents } from "./agents.js";
import {
	type WorktreeBaseline,
	applyBaseline,
	applyPatchToRepo,
	captureBaseline,
	captureDeltaPatch,
	cleanupWorktree,
	ensureWorktree,
	getRepoRoot,
} from "./worktree.js";

// ── Constants ──────────────────────────────────────────────────────────

const MAX_PARALLEL_TASKS = 8;
const MAX_CONCURRENCY = 4;

/** Default agent used when no named agent is specified. */
const DEFAULT_AGENT: AgentConfig = {
	name: "default",
	description: "General-purpose subagent — parent controls role via task description",
	systemPrompt: "",
	source: "user",
	filePath: "(builtin)",
};

// ── Types ──────────────────────────────────────────────────────────────

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

interface SingleResult {
	agent: string;
	agentSource: "user" | "project" | "unknown";
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
	patchPath?: string;
	patchApplied?: boolean;
}

interface SubagentDetails {
	mode: "single" | "parallel" | "chain";
	agentScope: AgentScope;
	projectAgentsDir: string | null;
	results: SingleResult[];
	isolated: boolean;
	patchSummary?: string;
}

/** Per-task overrides that can be specified inline. */
interface TaskOverrides {
	model?: string;
	tools?: string;
	systemPrompt?: string;
}

// ── Agent resolution ───────────────────────────────────────────────────

/**
 * Resolve the effective agent config for a task.
 * If agentName is provided, look it up from discovered agents.
 * If not, use the default agent. Then apply any per-task overrides.
 */
function resolveAgent(
	agents: AgentConfig[],
	agentName: string | undefined,
	overrides: TaskOverrides,
): AgentConfig | { error: string } {
	let base: AgentConfig;

	if (agentName) {
		const found = agents.find((a) => a.name === agentName);
		if (!found) {
			const available = agents.map((a) => `"${a.name}"`).join(", ");
			return { error: `Unknown agent: "${agentName}". Available: ${available || "none"} (or omit agent to use default).` };
		}
		base = { ...found };
	} else {
		base = { ...DEFAULT_AGENT };
	}

	if (overrides.model) base.model = overrides.model;
	if (overrides.tools) {
		base.tools = overrides.tools.split(",").map((t) => t.trim()).filter(Boolean);
	}
	if (overrides.systemPrompt) {
		base.systemPrompt = base.systemPrompt
			? `${base.systemPrompt}\n\n${overrides.systemPrompt}`
			: overrides.systemPrompt;
	}

	return base;
}

// ── Helpers ────────────────────────────────────────────────────────────

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

function formatUsage(usage: UsageStats, model?: string): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

function aggregateUsage(results: SingleResult[]): UsageStats {
	const total: UsageStats = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 };
	for (const r of results) {
		total.input += r.usage.input;
		total.output += r.usage.output;
		total.cacheRead += r.usage.cacheRead;
		total.cacheWrite += r.usage.cacheWrite;
		total.cost += r.usage.cost;
		total.turns += r.usage.turns;
	}
	return total;
}

async function mapWithConcurrencyLimit<TIn, TOut>(
	items: TIn[],
	concurrency: number,
	fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
	if (items.length === 0) return [];
	const limit = Math.max(1, Math.min(concurrency, items.length));
	const results: TOut[] = new Array(items.length);
	let nextIndex = 0;
	const workers = new Array(limit).fill(null).map(async () => {
		while (true) {
			const current = nextIndex++;
			if (current >= items.length) return;
			results[current] = await fn(items[current], current);
		}
	});
	await Promise.all(workers);
	return results;
}

function writePromptToTempFile(agentName: string, prompt: string): { dir: string; filePath: string } {
	const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-subagent-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(tmpDir, `prompt-${safeName}.md`);
	fs.writeFileSync(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
	return { dir: tmpDir, filePath };
}

// ── Subprocess runner ──────────────────────────────────────────────────

type OnUpdateCallback = (partial: AgentToolResult<SubagentDetails>) => void;

/**
 * Spawn a pi subprocess for a single agent task.
 * Takes a resolved AgentConfig directly — caller handles lookup + overrides.
 */
async function runSingleAgent(
	cwd: string,
	agent: AgentConfig,
	task: string,
	agentCwd: string | undefined,
	step: number | undefined,
	signal: AbortSignal | undefined,
	onUpdate: OnUpdateCallback | undefined,
	makeDetails: (results: SingleResult[]) => SubagentDetails,
): Promise<SingleResult> {
	const args: string[] = ["--mode", "json", "-p", "--no-session"];
	if (agent.model) args.push("--model", agent.model);
	if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));

	let tmpPromptDir: string | null = null;
	let tmpPromptPath: string | null = null;

	const currentResult: SingleResult = {
		agent: agent.name,
		agentSource: agent.source,
		task,
		exitCode: 0,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		model: agent.model,
		step,
	};

	const emitUpdate = () => {
		if (onUpdate) {
			onUpdate({
				content: [{ type: "text", text: getFinalOutput(currentResult.messages) || "(running...)" }],
				details: makeDetails([currentResult]),
			});
		}
	};

	try {
		if (agent.systemPrompt.trim()) {
			const tmp = writePromptToTempFile(agent.name, agent.systemPrompt);
			tmpPromptDir = tmp.dir;
			tmpPromptPath = tmp.filePath;
			args.push("--append-system-prompt", tmpPromptPath);
		}

		args.push(`Task: ${task}`);
		let wasAborted = false;

		const exitCode = await new Promise<number>((resolve) => {
			const proc = spawn("pi", args, {
				cwd: agentCwd ?? cwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});
			let buffer = "";

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}
				if (event.type === "message_end" && event.message) {
					const msg = event.message as Message;
					currentResult.messages.push(msg);
					if (msg.role === "assistant") {
						currentResult.usage.turns++;
						const usage = msg.usage;
						if (usage) {
							currentResult.usage.input += usage.input || 0;
							currentResult.usage.output += usage.output || 0;
							currentResult.usage.cacheRead += usage.cacheRead || 0;
							currentResult.usage.cacheWrite += usage.cacheWrite || 0;
							currentResult.usage.cost += usage.cost?.total || 0;
							currentResult.usage.contextTokens = usage.totalTokens || 0;
						}
						if (!currentResult.model && msg.model) currentResult.model = msg.model;
						if (msg.stopReason) currentResult.stopReason = msg.stopReason;
						if (msg.errorMessage) currentResult.errorMessage = msg.errorMessage;
					}
					emitUpdate();
				}
				if (event.type === "tool_result_end" && event.message) {
					currentResult.messages.push(event.message as Message);
					emitUpdate();
				}
			};

			proc.stdout.on("data", (data: Buffer) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data: Buffer) => {
				currentResult.stderr += data.toString();
			});

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});

			proc.on("error", () => resolve(1));

			if (signal) {
				const killProc = () => {
					wasAborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}
		});

		currentResult.exitCode = exitCode;
		if (wasAborted) throw new Error("Subagent was aborted");
		return currentResult;
	} finally {
		if (tmpPromptPath) try { fs.unlinkSync(tmpPromptPath); } catch { /* ignore */ }
		if (tmpPromptDir) try { fs.rmdirSync(tmpPromptDir); } catch { /* ignore */ }
	}
}

// ── Extension ──────────────────────────────────────────────────────────

/** Shared override fields for per-task customization. */
const OverrideFields = {
	model: Type.Optional(Type.String({ description: "Model override for this task (e.g. claude-haiku-4-5)" })),
	tools: Type.Optional(Type.String({ description: "Comma-separated tool list override (e.g. read,grep,find,ls)" })),
	systemPrompt: Type.Optional(Type.String({ description: "Additional system prompt appended to agent's base prompt" })),
};

const TaskItem = Type.Object({
	task: Type.String({ description: "Task to delegate" }),
	agent: Type.Optional(Type.String({ description: "Named agent preset (omit to use default)" })),
	cwd: Type.Optional(Type.String({ description: "Working directory (ignored in isolated mode)" })),
	...OverrideFields,
});

const ChainItem = Type.Object({
	task: Type.String({ description: "Task with optional {previous} placeholder for prior output" }),
	agent: Type.Optional(Type.String({ description: "Named agent preset (omit to use default)" })),
	cwd: Type.Optional(Type.String({ description: "Working directory (ignored in isolated mode)" })),
	...OverrideFields,
});

const AgentScopeSchema = StringEnum(["user", "project", "both"] as const, {
	description: 'Which agent directories to use. Default: "user".',
	default: "user",
});

const SubagentParams = Type.Object({
	task: Type.Optional(Type.String({ description: "Task (single mode)" })),
	agent: Type.Optional(Type.String({ description: "Named agent preset (single mode, omit to use default)" })),
	tasks: Type.Optional(Type.Array(TaskItem, { description: "Parallel tasks" })),
	chain: Type.Optional(Type.Array(ChainItem, { description: "Sequential tasks with {previous}" })),
	isolated: Type.Optional(
		Type.Boolean({
			description:
				"Run each subagent in an isolated git worktree. " +
				"Returns delta patches instead of modifying the working tree directly. " +
				"Use when subagents edit overlapping files in parallel.",
			default: false,
		}),
	),
	agentScope: Type.Optional(AgentScopeSchema),
	confirmProjectAgents: Type.Optional(
		Type.Boolean({ description: "Prompt before running project-local agents. Default: true.", default: true }),
	),
	cwd: Type.Optional(Type.String({ description: "Working directory (single mode, ignored when isolated)" })),
	...OverrideFields,
});

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate tasks to specialized subagents with isolated context windows.",
			"Modes: single (task + optional agent), parallel (tasks array), chain (sequential with {previous}).",
			"Each task can override model, tools, and systemPrompt inline.",
			"If no agent name is given, a default agent is used and you control its behavior entirely via the task description and overrides.",
			"Named agent presets from ~/.pi/agent/agents/*.md provide reusable configurations (model, tools, system prompt).",
			"Set isolated: true to run each subagent in its own git worktree for safe parallel file edits.",
		].join(" "),
		parameters: SubagentParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const agentScope: AgentScope = params.agentScope ?? "user";
			const discovery = discoverAgents(ctx.cwd, agentScope);
			const agents = discovery.agents;
			const isolated = params.isolated === true;

			const hasChain = (params.chain?.length ?? 0) > 0;
			const hasTasks = (params.tasks?.length ?? 0) > 0;
			const hasSingle = Boolean(params.task);
			const modeCount = Number(hasChain) + Number(hasTasks) + Number(hasSingle);

			const mode: "single" | "parallel" | "chain" = hasChain ? "chain" : hasTasks ? "parallel" : "single";

			const makeDetails =
				(results: SingleResult[]): SubagentDetails => ({
					mode,
					agentScope,
					projectAgentsDir: discovery.projectAgentsDir,
					results,
					isolated,
				});

			if (modeCount !== 1) {
				const available = agents.map((a) => `${a.name} (${a.source})`).join(", ");
				return {
					content: [{
						type: "text",
						text: `Invalid parameters. Provide exactly one of: task (single), tasks (parallel), or chain.\n` +
							`Available agent presets: ${available || "none"} (all optional — omit agent to use default).`,
					}],
					details: makeDetails([]),
				};
			}

			// Validate git repo for isolated mode
			let repoRoot: string | null = null;
			let baseline: WorktreeBaseline | null = null;
			if (isolated) {
				try {
					repoRoot = await getRepoRoot(ctx.cwd);
					baseline = await captureBaseline(repoRoot);
				} catch (err) {
					const msg = err instanceof Error ? err.message : String(err);
					return {
						content: [{ type: "text", text: `Isolated mode requires a git repository. ${msg}` }],
						details: makeDetails([]),
					};
				}
			}

			// Confirm project agents
			if ((agentScope === "project" || agentScope === "both") && (params.confirmProjectAgents ?? true) && ctx.hasUI) {
				const requestedNames = new Set<string>();
				if (params.chain) for (const s of params.chain) if (s.agent) requestedNames.add(s.agent);
				if (params.tasks) for (const t of params.tasks) if (t.agent) requestedNames.add(t.agent);
				if (params.agent) requestedNames.add(params.agent);

				const projectAgents = Array.from(requestedNames)
					.map((n) => agents.find((a) => a.name === n))
					.filter((a): a is AgentConfig => a?.source === "project");

				if (projectAgents.length > 0) {
					const names = projectAgents.map((a) => a.name).join(", ");
					const dir = discovery.projectAgentsDir ?? "(unknown)";
					const ok = await ctx.ui.confirm(
						"Run project-local agents?",
						`Agents: ${names}\nSource: ${dir}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
					);
					if (!ok) {
						return {
							content: [{ type: "text", text: "Canceled: project-local agents not approved." }],
							details: makeDetails([]),
						};
					}
				}
			}

			// ── Helper: resolve agent + run with optional worktree ──────

			const runIsolatedTask = async (
				agentName: string | undefined,
				task: string,
				overrides: TaskOverrides,
				agentCwd: string | undefined,
				step: number | undefined,
				taskSignal: AbortSignal | undefined,
				taskOnUpdate: OnUpdateCallback | undefined,
			): Promise<SingleResult> => {
				const resolved = resolveAgent(agents, agentName, overrides);
				if ("error" in resolved) {
					return {
						agent: agentName ?? "default",
						agentSource: "unknown",
						task,
						exitCode: 1,
						messages: [],
						stderr: resolved.error,
						usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
						step,
					};
				}

				const agent = resolved;

				if (!isolated || !repoRoot || !baseline) {
					return runSingleAgent(ctx.cwd, agent, task, agentCwd, step, taskSignal, taskOnUpdate, makeDetails);
				}

				const taskId = `${agent.name}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
				let worktreeDir: string | undefined;
				try {
					worktreeDir = await ensureWorktree(repoRoot, taskId);
					await applyBaseline(worktreeDir, baseline);

					const result = await runSingleAgent(
						ctx.cwd,
						agent,
						task,
						worktreeDir,
						step,
						taskSignal,
						taskOnUpdate,
						makeDetails,
					);

					const patch = await captureDeltaPatch(worktreeDir, baseline);
					if (patch.trim()) {
						const patchDir = path.join(os.tmpdir(), "pi-subagent-patches");
						fs.mkdirSync(patchDir, { recursive: true });
						const patchPath = path.join(patchDir, `${taskId}.patch`);
						fs.writeFileSync(patchPath, patch, "utf-8");
						result.patchPath = patchPath;
					}

					return result;
				} finally {
					if (worktreeDir && repoRoot) {
						await cleanupWorktree(worktreeDir, repoRoot);
					}
				}
			};

			// ── Single mode ────────────────────────────────────────────

			if (hasSingle && params.task) {
				const result = await runIsolatedTask(
					params.agent,
					params.task,
					{ model: params.model, tools: params.tools, systemPrompt: params.systemPrompt },
					params.cwd,
					undefined,
					signal,
					(partial) => onUpdate?.(partial),
				);

				if (isolated && result.patchPath && repoRoot) {
					const patch = fs.readFileSync(result.patchPath, "utf-8");
					const applyResult = await applyPatchToRepo(repoRoot, patch);
					result.patchApplied = applyResult.applied;
				}

				const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
				const details = makeDetails([result]);
				if (isolated) {
					details.patchSummary = result.patchApplied
						? "Patch applied successfully."
						: result.patchPath
							? `Patch conflict. Manual review needed: ${result.patchPath}`
							: "No changes produced.";
				}

				if (isError) {
					const errorMsg = result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
					return {
						content: [{ type: "text", text: `Agent ${result.stopReason || "failed"}: ${errorMsg}` }],
						details,
						isError: true,
					};
				}
				return {
					content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
					details,
				};
			}

			// ── Chain mode ─────────────────────────────────────────────

			if (hasChain && params.chain && params.chain.length > 0) {
				const results: SingleResult[] = [];
				let previousOutput = "";

				for (let i = 0; i < params.chain.length; i++) {
					const step = params.chain[i];
					const taskWithContext = step.task.replace(/\{previous\}/g, previousOutput);

					const result = await runIsolatedTask(
						step.agent,
						taskWithContext,
						{ model: step.model, tools: step.tools, systemPrompt: step.systemPrompt },
						step.cwd,
						i + 1,
						signal,
						onUpdate
							? (partial) => {
									const currentResult = partial.details?.results[0];
									if (currentResult) {
										onUpdate({
											content: partial.content,
											details: makeDetails([...results, currentResult]),
										});
									}
								}
							: undefined,
					);

					if (isolated && result.patchPath && repoRoot) {
						const patch = fs.readFileSync(result.patchPath, "utf-8");
						const applyResult = await applyPatchToRepo(repoRoot, patch);
						result.patchApplied = applyResult.applied;
						if (applyResult.applied) {
							baseline = await captureBaseline(repoRoot);
						}
					}

					results.push(result);

					const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
					if (isError) {
						const errorMsg = result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
						return {
							content: [{ type: "text", text: `Chain stopped at step ${i + 1} (${step.agent ?? "default"}): ${errorMsg}` }],
							details: makeDetails(results),
							isError: true,
						};
					}
					previousOutput = getFinalOutput(result.messages);
				}

				const details = makeDetails(results);
				if (isolated) {
					const applied = results.filter((r) => r.patchApplied).length;
					const withPatches = results.filter((r) => r.patchPath).length;
					details.patchSummary = `${applied}/${withPatches} patches applied.`;
				}
				return {
					content: [{ type: "text", text: getFinalOutput(results[results.length - 1].messages) || "(no output)" }],
					details,
				};
			}

			// ── Parallel mode ──────────────────────────────────────────

			if (hasTasks && params.tasks && params.tasks.length > 0) {
				if (params.tasks.length > MAX_PARALLEL_TASKS) {
					return {
						content: [{ type: "text", text: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_TASKS}.` }],
						details: makeDetails([]),
					};
				}

				const allResults: SingleResult[] = new Array(params.tasks.length);
				for (let i = 0; i < params.tasks.length; i++) {
					allResults[i] = {
						agent: params.tasks[i].agent ?? "default",
						agentSource: "unknown",
						task: params.tasks[i].task,
						exitCode: -1,
						messages: [],
						stderr: "",
						usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
					};
				}

				const emitParallelUpdate = () => {
					if (onUpdate) {
						const running = allResults.filter((r) => r.exitCode === -1).length;
						const done = allResults.filter((r) => r.exitCode !== -1).length;
						onUpdate({
							content: [{ type: "text", text: `Parallel: ${done}/${allResults.length} done, ${running} running...` }],
							details: makeDetails([...allResults]),
						});
					}
				};

				const results = await mapWithConcurrencyLimit(params.tasks, MAX_CONCURRENCY, async (t, index) => {
					const result = await runIsolatedTask(
						t.agent,
						t.task,
						{ model: t.model, tools: t.tools, systemPrompt: t.systemPrompt },
						t.cwd,
						undefined,
						signal,
						(partial) => {
							if (partial.details?.results[0]) {
								allResults[index] = partial.details.results[0];
								emitParallelUpdate();
							}
						},
					);
					allResults[index] = result;
					emitParallelUpdate();
					return result;
				});

				if (isolated && repoRoot) {
					const patchTexts: string[] = [];
					for (const r of results) {
						if (r.patchPath) {
							const text = fs.readFileSync(r.patchPath, "utf-8");
							if (text.trim()) patchTexts.push(text.endsWith("\n") ? text : `${text}\n`);
						}
					}

					if (patchTexts.length > 0) {
						const combined = patchTexts.join("");
						const applyResult = await applyPatchToRepo(repoRoot, combined);
						for (const r of results) {
							if (r.patchPath) r.patchApplied = applyResult.applied;
						}
					}
				}

				const details = makeDetails(results);
				if (isolated) {
					const applied = results.some((r) => r.patchApplied === true);
					const hasPatches = results.some((r) => r.patchPath);
					if (!hasPatches) {
						details.patchSummary = "No changes produced.";
					} else if (applied) {
						details.patchSummary = "All patches applied successfully.";
					} else {
						const paths = results.filter((r) => r.patchPath).map((r) => r.patchPath);
						details.patchSummary = `Patch conflict. Manual review needed:\n${paths.join("\n")}`;
					}
				}

				const successCount = results.filter((r) => r.exitCode === 0).length;
				const summaries = results.map((r) => {
					const output = getFinalOutput(r.messages);
					const preview = output.slice(0, 100) + (output.length > 100 ? "..." : "");
					const patchNote = r.patchPath
						? r.patchApplied ? " [patch applied]" : " [patch conflict]"
						: "";
					return `[${r.agent}] ${r.exitCode === 0 ? "completed" : "failed"}${patchNote}: ${preview || "(no output)"}`;
				});

				return {
					content: [{ type: "text", text: `Parallel: ${successCount}/${results.length} succeeded\n\n${summaries.join("\n\n")}` }],
					details,
				};
			}

			const available = agents.map((a) => `${a.name} (${a.source})`).join(", ");
			return {
				content: [{
					type: "text",
					text: `Invalid parameters. Provide task, tasks, or chain.\n` +
						`Available agent presets: ${available || "none"} (all optional — omit agent to use default).`,
				}],
				details: makeDetails([]),
			};
		},

		// ── Rendering ──────────────────────────────────────────────────

		renderCall(args, theme) {
			const iso = args.isolated ? theme.fg("warning", " [isolated]") : "";
			const agentLabel = (name?: string, overrides?: TaskOverrides) => {
				let label = theme.fg("accent", name ?? "default");
				const extras: string[] = [];
				if (overrides?.model) extras.push(overrides.model);
				if (overrides?.tools) extras.push(`tools:${overrides.tools}`);
				if (extras.length > 0) label += theme.fg("dim", ` (${extras.join(", ")})`);
				return label;
			};

			if (args.chain && args.chain.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `chain (${args.chain.length} steps)`) +
					iso;
				for (let i = 0; i < Math.min(args.chain.length, 3); i++) {
					const step = args.chain[i];
					const cleanTask = step.task.replace(/\{previous\}/g, "").trim();
					const preview = cleanTask.length > 40 ? `${cleanTask.slice(0, 40)}...` : cleanTask;
					text += `\n  ${theme.fg("muted", `${i + 1}.`)} ${agentLabel(step.agent, step)}${theme.fg("dim", ` ${preview}`)}`;
				}
				if (args.chain.length > 3) text += `\n  ${theme.fg("muted", `... +${args.chain.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}

			if (args.tasks && args.tasks.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `parallel (${args.tasks.length} tasks)`) +
					iso;
				for (const t of args.tasks.slice(0, 3)) {
					const preview = t.task.length > 40 ? `${t.task.slice(0, 40)}...` : t.task;
					text += `\n  ${agentLabel(t.agent, t)}${theme.fg("dim", ` ${preview}`)}`;
				}
				if (args.tasks.length > 3) text += `\n  ${theme.fg("muted", `... +${args.tasks.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}

			const preview = args.task ? (args.task.length > 60 ? `${args.task.slice(0, 60)}...` : args.task) : "...";
			let text =
				theme.fg("toolTitle", theme.bold("subagent ")) +
				agentLabel(args.agent, args) +
				iso;
			text += `\n  ${theme.fg("dim", preview)}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as SubagentDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			const renderPatchNote = (r: SingleResult): string => {
				if (!details.isolated || !r.patchPath) return "";
				return r.patchApplied
					? theme.fg("success", " [patch applied]")
					: theme.fg("error", " [patch conflict]");
			};

			// Single mode
			if (details.mode === "single" && details.results.length === 1) {
				const r = details.results[0];
				const isError = r.exitCode !== 0 || r.stopReason === "error" || r.stopReason === "aborted";
				const icon = isError ? theme.fg("error", "x") : theme.fg("success", "ok");
				const finalOutput = getFinalOutput(r.messages);

				if (expanded) {
					const container = new Container();
					let header = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}${renderPatchNote(r)}`;
					container.addChild(new Text(header, 0, 0));
					if (isError && r.errorMessage) container.addChild(new Text(theme.fg("error", `Error: ${r.errorMessage}`), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "--- Task ---"), 0, 0));
					container.addChild(new Text(theme.fg("dim", r.task), 0, 0));
					if (finalOutput) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("muted", "--- Output ---"), 0, 0));
						container.addChild(new Markdown(finalOutput.trim(), 0, 0, getMarkdownTheme()));
					}
					if (details.patchSummary) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("muted", "--- Patch ---"), 0, 0));
						container.addChild(new Text(theme.fg("dim", details.patchSummary), 0, 0));
					}
					const usageStr = formatUsage(r.usage, r.model);
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", usageStr), 0, 0));
					}
					return container;
				}

				let text = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${renderPatchNote(r)}`;
				if (isError && r.errorMessage) text += `\n${theme.fg("error", `Error: ${r.errorMessage}`)}`;
				else if (finalOutput) {
					const preview = finalOutput.split("\n").slice(0, 3).join("\n");
					text += `\n${theme.fg("toolOutput", preview)}`;
				} else {
					text += `\n${theme.fg("muted", "(no output)")}`;
				}
				if (details.patchSummary) text += `\n${theme.fg("dim", details.patchSummary)}`;
				const usageStr = formatUsage(r.usage, r.model);
				if (usageStr) text += `\n${theme.fg("dim", usageStr)}`;
				return new Text(text, 0, 0);
			}

			// Chain mode
			if (details.mode === "chain") {
				const successCount = details.results.filter((r) => r.exitCode === 0).length;
				const icon = successCount === details.results.length ? theme.fg("success", "ok") : theme.fg("error", "x");
				let text = `${icon} ${theme.fg("toolTitle", theme.bold("chain "))}${theme.fg("accent", `${successCount}/${details.results.length} steps`)}`;
				for (const r of details.results) {
					const rIcon = r.exitCode === 0 ? theme.fg("success", "ok") : theme.fg("error", "x");
					text += `\n\n${theme.fg("muted", `--- Step ${r.step}: `)}${theme.fg("accent", r.agent)} ${rIcon}${renderPatchNote(r)}`;
					const output = getFinalOutput(r.messages);
					if (output) {
						const preview = expanded ? output : output.split("\n").slice(0, 3).join("\n");
						text += `\n${theme.fg("toolOutput", preview)}`;
					} else {
						text += `\n${theme.fg("muted", "(no output)")}`;
					}
				}
				if (details.patchSummary) text += `\n\n${theme.fg("dim", details.patchSummary)}`;
				const usageStr = formatUsage(aggregateUsage(details.results));
				if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				return new Text(text, 0, 0);
			}

			// Parallel mode
			if (details.mode === "parallel") {
				const running = details.results.filter((r) => r.exitCode === -1).length;
				const successCount = details.results.filter((r) => r.exitCode === 0).length;
				const isRunning = running > 0;
				const icon = isRunning ? theme.fg("warning", "...") : theme.fg("success", "ok");
				const status = isRunning
					? `${successCount}/${details.results.length} done, ${running} running`
					: `${successCount}/${details.results.length} tasks`;

				let text = `${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`;
				for (const r of details.results) {
					const rIcon = r.exitCode === -1
						? theme.fg("warning", "...")
						: r.exitCode === 0
							? theme.fg("success", "ok")
							: theme.fg("error", "x");
					text += `\n\n${theme.fg("muted", "--- ")}${theme.fg("accent", r.agent)} ${rIcon}${renderPatchNote(r)}`;
					const output = getFinalOutput(r.messages);
					if (output) {
						const preview = expanded ? output : output.split("\n").slice(0, 3).join("\n");
						text += `\n${theme.fg("toolOutput", preview)}`;
					} else {
						text += `\n${theme.fg("muted", r.exitCode === -1 ? "(running...)" : "(no output)")}`;
					}
				}
				if (details.patchSummary) text += `\n\n${theme.fg("dim", details.patchSummary)}`;
				if (!isRunning) {
					const usageStr = formatUsage(aggregateUsage(details.results));
					if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				}
				return new Text(text, 0, 0);
			}

			const text = result.content[0];
			return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
		},
	});
}
