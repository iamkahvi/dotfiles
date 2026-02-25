/**
 * Slack Extension - Wraps callm-for-slack MCP tools as pi tools
 *
 * Provides LLM-callable tools for reading Slack messages, searching interactions,
 * getting summaries, and executing arbitrary Slack API calls.
 *
 * Requires: npx mcporter (with callm-for-slack configured)
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	truncateHead,
} from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const MCPORTER_SERVER = "callm-for-slack";
const NODE20_BIN = `${process.env.HOME}/.nvm/versions/node/v20.19.1/bin`;

async function callMcporter(
	pi: ExtensionAPI,
	func: string,
	args: Record<string, string | boolean | undefined>,
	signal?: AbortSignal,
): Promise<{ stdout: string; stderr: string; code: number }> {
	const parts: string[] = [];
	for (const [key, value] of Object.entries(args)) {
		if (value === undefined) continue;
		parts.push(`${key}: ${typeof value === "string" ? JSON.stringify(value) : value}`);
	}
	const argStr = parts.length > 0 ? `(${parts.join(", ")})` : "";
	const callArg = `${MCPORTER_SERVER}.${func}${argStr}`;
	const result = await pi.exec(
		"bash",
		["-c", `export PATH="${NODE20_BIN}:$PATH" && exec npx mcporter call "$1"`, "--", callArg],
		{ signal, timeout: 120_000 },
	);
	return { stdout: result.stdout, stderr: result.stderr, code: result.code };
}

function truncateOutput(output: string): { text: string; truncated: boolean } {
	const truncation = truncateHead(output, {
		maxLines: DEFAULT_MAX_LINES,
		maxBytes: DEFAULT_MAX_BYTES,
	});

	if (!truncation.truncated) {
		return { text: truncation.content, truncated: false };
	}

	let text = truncation.content;
	text += `\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines`;
	text += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}).]`;
	return { text, truncated: true };
}

function makeResult(stdout: string, stderr: string, code: number) {
	if (code !== 0) {
		const errMsg = stderr || stdout || `mcporter exited with code ${code}`;
		return {
			content: [{ type: "text" as const, text: errMsg }],
			details: { error: true },
			isError: true,
		};
	}
	const { text } = truncateOutput(stdout);
	return {
		content: [{ type: "text" as const, text }],
		details: { error: false },
	};
}

export default function slackExtension(pi: ExtensionAPI) {
	// -- slack_user_info --
	pi.registerTool({
		name: "slack_user_info",
		label: "Slack User Info",
		description:
			'Get information about a Slack user. Pass "me" for the current user.',
		parameters: Type.Object({
			username: Type.Optional(
				Type.String({
					description:
						'Username to look up, or "me" for current user. Defaults to "me".',
				}),
			),
		}),
		async execute(_id, params, signal) {
			const { stdout, stderr, code } = await callMcporter(
				pi,
				"user_info",
				{ username: params.username ?? "me" },
				signal,
			);
			return makeResult(stdout, stderr, code);
		},
		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("slack_user_info "));
			text += theme.fg("accent", args.username ?? "me");
			return new Text(text, 0, 0);
		},
	});

	// -- slack_eval --
	pi.registerTool({
		name: "slack_eval",
		label: "Slack Eval",
		description: `Execute a JavaScript async function against the Slack API. The function receives a SlackClient instance as its first argument.

SlackClient interface:
  slack.info - workspace info (token, id, user_id, url, domain, name)
  slack.user - current user profile
  slack.users - cached user profiles by ID
  slack.api.users.list/info/profile.get/profile.set/conversations
  slack.api.conversations.list/history/replies/info/create/invite/join/leave
  slack.api.chat.postMessage/update/delete/postEphemeral
  slack.api.reactions.add/remove/get
  slack.api.search.messages/files (params: query, sort, sort_dir, count, page)
  slack.api.bookmarks.list/add/edit/remove

Search query syntax:
  - Space-separated AND terms: "with:me with:@bob.dole on:2025-04-20"
  - "with:me" scopes to current user (not default)
  - Date filters: before:, after: (exclusive), on:, during:
  - after:2025-04-24 returns messages >= 2025-04-25T00:00:00Z

Tips:
  - Do heavy filtering inside the function, return minimal data
  - Use multiple calls for paged/hierarchical data

Output is truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)}.`,
		parameters: Type.Object({
			function: Type.String({
				description:
					"JavaScript async function body. Receives SlackClient as first arg. Must export default async function.",
			}),
		}),
		async execute(_id, params, signal) {
			const { stdout, stderr, code } = await callMcporter(
				pi,
				"evaluate_repl_function",
				{ function: params.function },
				signal,
			);
			return makeResult(stdout, stderr, code);
		},
		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("slack_eval "));
			const preview = args.function.split("\n")[0].slice(0, 80);
			text += theme.fg("dim", preview);
			if (args.function.length > 80) text += theme.fg("muted", "...");
			return new Text(text, 0, 0);
		},
		renderResult(result, { expanded }, theme) {
			if (result.details?.error) {
				const errText =
					result.content[0]?.type === "text" ? result.content[0].text : "Error";
				return new Text(theme.fg("error", errText.slice(0, 200)), 0, 0);
			}
			const content = result.content[0];
			const raw = content?.type === "text" ? content.text : "";
			const lineCount = raw.split("\n").length;
			let text = theme.fg("success", `Done (${lineCount} lines)`);
			if (expanded) {
				const lines = raw.split("\n").slice(0, 30);
				for (const line of lines) {
					text += `\n${theme.fg("dim", line)}`;
				}
				if (lineCount > 30) {
					text += `\n${theme.fg("muted", `... ${lineCount - 30} more lines`)}`;
				}
			}
			return new Text(text, 0, 0);
		},
	});

	// -- slack_discussion_summary --
	pi.registerTool({
		name: "slack_discussion_summary",
		label: "Slack Discussion Summary",
		description:
			"Get an LLM-generated summary of Slack discussions within a date range. Only full days supported.",
		parameters: Type.Object({
			starting: Type.Optional(
				Type.String({ description: "Start date YYYY-MM-DD. Defaults to today." }),
			),
			ending: Type.Optional(
				Type.String({
					description: "End date YYYY-MM-DD. Defaults to same as starting.",
				}),
			),
		}),
		async execute(_id, params, signal) {
			const { stdout, stderr, code } = await callMcporter(
				pi,
				"get_discussion_summary",
				{ starting: params.starting, ending: params.ending },
				signal,
			);
			return makeResult(stdout, stderr, code);
		},
		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("slack_discussion_summary "));
			if (args.starting) text += theme.fg("accent", args.starting);
			if (args.ending) text += theme.fg("muted", ` to ${args.ending}`);
			return new Text(text, 0, 0);
		},
	});

	// -- slack_catchup --
	pi.registerTool({
		name: "slack_catchup",
		label: "Slack Catchup",
		description:
			"Get a summary of unread Slack messages and DMs awaiting response.",
		parameters: Type.Object({
			includeUnanswered: Type.Optional(
				Type.Boolean({
					description:
						"Include DMs where you haven't responded yet. Defaults to true.",
				}),
			),
		}),
		async execute(_id, params, signal) {
			const { stdout, stderr, code } = await callMcporter(
				pi,
				"get_catchup_summary",
				{
					includeUnanswered:
						params.includeUnanswered !== undefined
							? params.includeUnanswered
							: undefined,
				},
				signal,
			);
			return makeResult(stdout, stderr, code);
		},
		renderCall(_args, theme) {
			return new Text(
				theme.fg("toolTitle", theme.bold("slack_catchup")),
				0,
				0,
			);
		},
	});

	// -- slack_technical_summary --
	pi.registerTool({
		name: "slack_technical_summary",
		label: "Slack Technical Summary",
		description:
			"Get an LLM-generated summary of technical/directional discussions grouped by project. Filters out social banter, focuses on architecture, implementation, and planning.",
		parameters: Type.Object({
			starting: Type.Optional(
				Type.String({ description: "Start date YYYY-MM-DD. Defaults to today." }),
			),
			ending: Type.Optional(
				Type.String({
					description: "End date YYYY-MM-DD. Defaults to same as starting.",
				}),
			),
		}),
		async execute(_id, params, signal) {
			const { stdout, stderr, code } = await callMcporter(
				pi,
				"get_technical_discussion_summary",
				{ starting: params.starting, ending: params.ending },
				signal,
			);
			return makeResult(stdout, stderr, code);
		},
		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("slack_technical_summary "));
			if (args.starting) text += theme.fg("accent", args.starting);
			if (args.ending) text += theme.fg("muted", ` to ${args.ending}`);
			return new Text(text, 0, 0);
		},
	});

	// -- slack_user_interactions --
	pi.registerTool({
		name: "slack_user_interactions",
		label: "Slack User Interactions",
		description:
			"Search for interactions between you and another Slack user. Returns raw message contexts by default, or AI summary if requested.",
		parameters: Type.Object({
			username: Type.String({
				description:
					'Slack username (e.g., "john.doe") or user ID to search interactions with.',
			}),
			starting: Type.Optional(
				Type.String({ description: "Start date YYYY-MM-DD. Defaults to today." }),
			),
			ending: Type.Optional(
				Type.String({
					description: "End date YYYY-MM-DD. Defaults to same as starting.",
				}),
			),
			summarize: Type.Optional(
				Type.Boolean({
					description: "Generate AI summary of interactions. Defaults to false.",
				}),
			),
		}),
		async execute(_id, params, signal) {
			const { stdout, stderr, code } = await callMcporter(
				pi,
				"get_user_interactions",
				{
					username: params.username,
					starting: params.starting,
					ending: params.ending,
					summarize:
						params.summarize !== undefined ? params.summarize : undefined,
				},
				signal,
			);
			return makeResult(stdout, stderr, code);
		},
		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("slack_user_interactions "));
			text += theme.fg("accent", args.username);
			if (args.starting) text += theme.fg("muted", ` from ${args.starting}`);
			if (args.ending) text += theme.fg("muted", ` to ${args.ending}`);
			return new Text(text, 0, 0);
		},
	});
}
