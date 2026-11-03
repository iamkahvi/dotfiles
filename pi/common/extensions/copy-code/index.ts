/**
 * Copy Code Extension
 *
 * Adds a GitHub-style "copy" button to the top-right of every fenced code block
 * rendered in the transcript.
 *
 * - Fullscreen mode (default tuiMode): click "⧉ copy" on the code block header.
 * - Regular mode: the header shows "⧉ /copy-code N"; run that command.
 *
 * Commands / shortcuts:
 *   /copy-code          Copy the code block from the latest assistant message that has one
 *                       (picker if that message has several)
 *   /copy-code N        Copy the block labelled N
 *   /copy-code last     Copy the most recent code block
 *   /copy-code pick     Pick from every code block in the current branch
 *   ctrl+shift+c        Same as /copy-code
 *
 * How it works (internals, pinned against pi 1.2.0):
 * - Wraps Markdown.prototype.renderToken to decorate `code` tokens' header line with an
 *   OSC 8 hyperlink `pi-copy-code:N`.
 * - In fullscreen, pi itself resolves OSC 8 clicks and calls `tui.openUrl(url)`. A zero-height
 *   widget grabs the TUI reference and wraps `openUrl` to intercept our scheme.
 * - All mutable state lives on globalThis so /reload does not double-wrap or orphan closures.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { copyToClipboard } from "@earendil-works/pi-coding-agent";
import { hyperlink, Markdown, stripTerminalSequences, visibleWidth } from "@earendil-works/pi-tui";

const SCHEME = "pi-copy-code:";
const STATE_KEY = Symbol.for("pi.copy-code.state");
const PATCHED_KEY = Symbol.for("pi.copy-code.openUrlPatched");
const WIDGET_KEY = "copy-code-hook";
const SHORTCUT = "ctrl+shift+c";
const MAX_REGISTRY = 5000;

interface CodeBlock {
	lang: string;
	text: string;
	closed: boolean;
}

interface RegistryEntry {
	num: number;
	lang: string;
	text: string;
}

interface State {
	/** Keyed by the rendered token text (tabs already expanded by pi). */
	byKey: Map<string, RegistryEntry>;
	byNum: Map<number, RegistryEntry>;
	nextNum: number;
	/** undefined until the hook widget renders once; treated as fullscreen (pi default). */
	fullscreen: boolean | undefined;
	originalRenderToken?: (...args: unknown[]) => string[];
	decorate?: (md: any, token: any, width: number, lines: string[]) => string[];
	onLink?: (url: string) => void;
	ui?: ExtensionContext["ui"];
}

function state(): State {
	const g = globalThis as any;
	g[STATE_KEY] ??= { byKey: new Map(), byNum: new Map(), nextNum: 1, fullscreen: undefined } satisfies State;
	return g[STATE_KEY];
}

// ---------------------------------------------------------------------------
// Fenced code block extraction (used for session lookup and tab recovery)
// ---------------------------------------------------------------------------

function stripIndent(line: string, n: number): string {
	let i = 0;
	while (i < n && i < line.length && (line[i] === " " || line[i] === "\t")) i++;
	return line.slice(i);
}

export function extractCodeBlocks(markdown: string): CodeBlock[] {
	const out: CodeBlock[] = [];
	let open: { indent: number; ch: string; len: number; lang: string; body: string[] } | null = null;

	for (const rawLine of markdown.split("\n")) {
		const line = rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
		if (!open) {
			const m = /^([ \t]*)(`{3,}|~{3,})(.*)$/.exec(line);
			if (!m) continue;
			const info = m[3] ?? "";
			if (m[2][0] === "`" && info.includes("`")) continue; // inline code like ```foo``` is not a fence
			open = { indent: m[1].length, ch: m[2][0], len: m[2].length, lang: info.trim().split(/\s+/)[0] ?? "", body: [] };
			continue;
		}
		const c = /^[ \t]*(`{3,}|~{3,})[ \t]*$/.exec(line);
		if (c && c[1][0] === open.ch && c[1].length >= open.len) {
			out.push({ lang: open.lang, text: open.body.join("\n"), closed: true });
			open = null;
			continue;
		}
		open.body.push(stripIndent(line, open.indent));
	}
	if (open) out.push({ lang: open.lang, text: open.body.join("\n"), closed: false });
	return out;
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

function register(key: string, text: string, lang: string): RegistryEntry {
	const s = state();
	const existing = s.byKey.get(key);
	if (existing) {
		// LRU bump
		s.byKey.delete(key);
		s.byKey.set(key, existing);
		return existing;
	}
	const entry: RegistryEntry = { num: s.nextNum++, lang, text };
	s.byKey.set(key, entry);
	s.byNum.set(entry.num, entry);
	while (s.byKey.size > MAX_REGISTRY) {
		const [oldKey, oldEntry] = s.byKey.entries().next().value as [string, RegistryEntry];
		s.byKey.delete(oldKey);
		s.byNum.delete(oldEntry.num);
	}
	return entry;
}

/** pi expands tabs to 3 spaces before lexing. Recover the original text so Makefiles/Go survive. */
const sourceCache = new WeakMap<object, { src: string; blocks: CodeBlock[] }>();
function recoverOriginal(md: any, tokenText: string): string {
	const src: unknown = md?.text;
	if (typeof src !== "string" || !src.includes("\t")) return tokenText;
	let cached = sourceCache.get(md);
	if (!cached || cached.src !== src) {
		cached = { src, blocks: extractCodeBlocks(src) };
		sourceCache.set(md, cached);
	}
	const hit = cached.blocks.find((b) => b.text.replace(/\t/g, "   ") === tokenText);
	return hit ? hit.text : tokenText;
}

function isClosedFence(raw: string): boolean {
	const trimmed = raw.replace(/\s+$/, "");
	const lines = trimmed.split("\n");
	if (lines.length < 2) return false;
	const open = /^[ \t]*(`{3,}|~{3,})/.exec(lines[0]!)?.[1];
	const close = /^[ \t]*(`{3,}|~{3,})[ \t]*$/.exec(lines[lines.length - 1]!)?.[1];
	return !!open && !!close && close[0] === open[0] && close.length >= open.length;
}

// ---------------------------------------------------------------------------
// Rendering decoration
// ---------------------------------------------------------------------------

function decorate(md: any, token: any, width: number, lines: string[]): string[] {
	if (token?.type !== "code" || token.codeBlockStyle === "indented") return lines;
	if (typeof token.raw !== "string" || !isClosedFence(token.raw)) return lines; // still streaming
	if (lines.length === 0 || !stripTerminalSequences(lines[0]!).startsWith("```")) return lines;

	const tokenText: string = token.text ?? "";
	const lang = String(token.lang ?? "").trim().split(/\s+/)[0] ?? "";
	const entry = register(tokenText, recoverOriginal(md, tokenText), lang);

	const fullscreen = state().fullscreen ?? true;
	const theme = md.theme ?? {};
	const link = typeof theme.link === "function" ? theme.link : (t: string) => t;
	const border = typeof theme.codeBlockBorder === "function" ? theme.codeBlockBorder : (t: string) => t;

	const label = fullscreen
		? hyperlink(link("⧉ copy"), `${SCHEME}${entry.num}`)
		: border(`⧉ /copy-code ${entry.num}`);

	const header = lines[0]!;
	const headerW = visibleWidth(header);
	const labelW = visibleWidth(label);
	if (headerW + 1 + labelW > width) return lines; // too narrow; command still works

	const out = lines.slice();
	out[0] = header + " ".repeat(width - headerW - labelW) + label;
	return out;
}

function installRenderPatch(): void {
	const s = state();
	s.decorate = decorate; // always point at the freshest module after /reload
	const proto = (Markdown as any)?.prototype;
	if (!proto || typeof proto.renderToken !== "function") return;
	if (s.originalRenderToken) return; // already wrapped by an earlier load

	s.originalRenderToken = proto.renderToken;
	proto.renderToken = function (this: any, token: any, width: number, ...rest: unknown[]) {
		const st = state();
		const lines = st.originalRenderToken!.call(this, token, width, ...rest) as string[];
		try {
			return st.decorate ? st.decorate(this, token, width, lines) : lines;
		} catch {
			return lines;
		}
	};
}

// ---------------------------------------------------------------------------
// Click interception via the TUI reference
// ---------------------------------------------------------------------------

function hookTui(tui: any): void {
	const s = state();
	const fs = tui?.mode === "fullscreen";
	const effective = s.fullscreen ?? true;
	s.fullscreen = fs;
	if (fs !== effective) {
		// Labels were rendered for the wrong mode; flush Markdown caches outside of render.
		setTimeout(() => {
			try {
				tui.invalidate?.();
				tui.requestRender?.();
			} catch {}
		}, 0);
	}
	if (!fs || tui[PATCHED_KEY] === true) return;

	// `tui` is pi's renderer proxy: reads/writes hit the current renderer, so a renderer swap
	// (mode toggle) yields an unpatched instance and we patch again.
	const orig = tui.openUrl as ((url: string) => void) | undefined;
	tui.openUrl = (url: string) => {
		if (typeof url === "string" && url.startsWith(SCHEME)) {
			state().onLink?.(url);
			return;
		}
		return orig?.(url);
	};
	tui[PATCHED_KEY] = true;
}

// ---------------------------------------------------------------------------
// Copy actions
// ---------------------------------------------------------------------------

async function copyText(ui: ExtensionContext["ui"] | undefined, text: string, lang: string): Promise<void> {
	try {
		await copyToClipboard(text);
		const n = text.length === 0 ? 0 : text.split("\n").length;
		ui?.notify(`Copied ${lang || "code"} block (${n} line${n === 1 ? "" : "s"}, ${text.length} chars)`, "info");
	} catch (err) {
		ui?.notify(`Copy failed: ${(err as Error).message}`, "error");
	}
}

function branchBlocks(ctx: ExtensionContext): CodeBlock[][] {
	// One array per assistant message, oldest first.
	const result: CodeBlock[][] = [];
	for (const entry of ctx.sessionManager.getBranch() as any[]) {
		if (entry?.type !== "message" || entry.message?.role !== "assistant") continue;
		const content = entry.message.content;
		const text = Array.isArray(content)
			? content
					.filter((c: any) => c?.type === "text" && typeof c.text === "string")
					.map((c: any) => c.text)
					.join("\n\n")
			: typeof content === "string"
				? content
				: "";
		const blocks = extractCodeBlocks(text);
		if (blocks.length) result.push(blocks);
	}
	return result;
}

function describe(block: CodeBlock, i: number): string {
	const first = block.text.split("\n").find((l) => l.trim().length > 0)?.trim() ?? "(empty)";
	const preview = first.length > 70 ? `${first.slice(0, 69)}…` : first;
	const n = block.text.split("\n").length;
	return `${i + 1}. [${block.lang || "text"}] ${preview}  (${n} line${n === 1 ? "" : "s"})`;
}

async function pick(ctx: ExtensionContext, blocks: CodeBlock[], title: string): Promise<void> {
	if (!ctx.hasUI) {
		ctx.ui.notify("Picker needs an interactive UI; use /copy-code last or /copy-code N", "warning");
		return;
	}
	const labels = blocks.map(describe);
	const choice = await ctx.ui.select(title, labels);
	if (!choice) return;
	const idx = labels.indexOf(choice);
	if (idx >= 0) await copyText(ctx.ui, blocks[idx]!.text, blocks[idx]!.lang);
}

async function runCopy(args: string, ctx: ExtensionContext): Promise<void> {
	const arg = args.trim().toLowerCase();

	if (/^\d+$/.test(arg)) {
		const entry = state().byNum.get(Number(arg));
		if (!entry) {
			ctx.ui.notify(`No code block #${arg} (labels reset on restart). Try /copy-code pick`, "warning");
			return;
		}
		await copyText(ctx.ui, entry.text, entry.lang);
		return;
	}

	const perMessage = branchBlocks(ctx);
	if (perMessage.length === 0) {
		ctx.ui.notify("No code blocks in this branch", "warning");
		return;
	}

	if (arg === "last") {
		const lastMsg = perMessage[perMessage.length - 1]!;
		const b = lastMsg[lastMsg.length - 1]!;
		await copyText(ctx.ui, b.text, b.lang);
		return;
	}

	if (arg === "pick" || arg === "all") {
		const all = perMessage.flat().reverse(); // newest first
		await pick(ctx, all, `Copy code block (${all.length}, newest first)`);
		return;
	}

	if (arg !== "") {
		ctx.ui.notify("Usage: /copy-code [N|last|pick]", "warning");
		return;
	}

	const latest = perMessage[perMessage.length - 1]!;
	if (latest.length === 1) {
		await copyText(ctx.ui, latest[0]!.text, latest[0]!.lang);
		return;
	}
	await pick(ctx, latest, `Copy code block from latest response (${latest.length})`);
}

// ---------------------------------------------------------------------------
// Extension entry
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
	installRenderPatch();

	pi.on("session_start", async (_event, ctx) => {
		const s = state();
		s.ui = ctx.ui;
		s.onLink = (url: string) => {
			const num = Number(url.slice(SCHEME.length));
			const entry = state().byNum.get(num);
			if (!entry) {
				state().ui?.notify(`Code block #${num} is no longer cached; use /copy-code pick`, "warning");
				return;
			}
			void copyText(state().ui, entry.text, entry.lang);
		};

		if (ctx.mode !== "tui") return;
		// Zero-height widget: only exists to receive the TUI reference on every frame.
		ctx.ui.setWidget(
			WIDGET_KEY,
			(tui) => ({
				render: () => {
					try {
						hookTui(tui);
					} catch {}
					return [];
				},
				invalidate: () => {},
			}),
			{ placement: "belowEditor" },
		);
	});

	pi.registerCommand("copy-code", {
		description: "Copy a code block from the conversation: /copy-code [N|last|pick]",
		getArgumentCompletions: (prefix) =>
			["last", "pick"]
				.filter((v) => v.startsWith(prefix.trim().toLowerCase()))
				.map((v) => ({ value: v, label: v })),
		handler: async (args, ctx) => runCopy(args, ctx),
	});

	pi.registerShortcut(SHORTCUT, {
		description: "Copy code block from the latest response",
		handler: async (ctx) => runCopy("", ctx),
	});
}
