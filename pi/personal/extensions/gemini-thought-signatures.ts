// Fixes Gemini 3.x tool-calling through OpenAI-compatible proxies that attach
// extra_content.google.thought_signature to function calls (and some plain
// responses). Gemini requires these signatures to be echoed back on the
// assistant tool_calls of subsequent requests, otherwise it rejects the call
// with 400 "Function call is missing a thought_signature in functionCall parts".
// pi-ai's openai-completions provider drops the field, so multi-turn tool use
// is broken for gemini-3.x behind such proxies.
//
// This extension patches globalThis.fetch to:
//   1. Inject stored signatures into outgoing request bodies
//      (assistant message tool_calls) for gemini-3.* models.
//   2. Capture new signatures from streamed SSE responses
//      (delta.tool_calls[].extra_content.google.thought_signature).
// Signatures are persisted to ~/.pi/agent/cache/gemini-thought-signatures.json
// so resumed sessions keep working across processes.
//
// Verified semantics against ai.tail37572.ts.net (gemini-3.5-flash):
//   - tool_call replay WITHOUT signature  -> 400 INVALID_ARGUMENT
//   - tool_call replay WITH signature     -> 200
//   - text-only assistant replay w/o sig  -> 200 (signatures not required)
// The pi-ai OpenAI client resolves fetch per-request from globalThis
// (openai SDK Shims.getDefaultFetch), so this patch is picked up everywhere.

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STORE_PATH = join(homedir(), ".pi", "agent", "cache", "gemini-thought-signatures.json");
const PROXY_HOST = "ai.tail37572.ts.net";
const CHAT_PATH = "/chat/completions";
const MODEL_RE = /^gemini-3/;
const MAX_ENTRIES = 1000;

interface ToolCallLike {
	id?: string;
	index?: number;
	extra_content?: { google?: { thought_signature?: string } };
}

// tool call id -> thought signature
const store = loadStore();

function loadStore(): Map<string, string> {
	try {
		const raw = JSON.parse(readFileSync(STORE_PATH, "utf8"));
		return new Map(Object.entries(raw).filter(([, v]) => typeof v === "string") as [string, string][]);
	} catch {
		return new Map();
	}
}

function persist(): void {
	try {
		while (store.size > MAX_ENTRIES) {
			const oldest = store.keys().next().value;
			if (oldest === undefined) break;
			store.delete(oldest);
		}
		mkdirSync(dirname(STORE_PATH), { recursive: true });
		const tmp = `${STORE_PATH}.tmp`;
		writeFileSync(tmp, JSON.stringify(Object.fromEntries(store)));
		renameSync(tmp, STORE_PATH);
	} catch {
		// best-effort; capture still works in-memory for this process
	}
}

// --- request side -----------------------------------------------------------

function injectSignatures(body: any): number {
	let injected = 0;
	const messages = body?.messages;
	if (!Array.isArray(messages)) return 0;
	for (const message of messages) {
		if (message?.role !== "assistant" || !Array.isArray(message.tool_calls)) continue;
		for (const tc of message.tool_calls as ToolCallLike[]) {
			if (!tc?.id || typeof tc.id !== "string") continue;
			if (tc.extra_content?.google?.thought_signature) continue; // never clobber
			const sig = store.get(tc.id);
			if (sig) {
				tc.extra_content = { google: { thought_signature: sig } };
				injected++;
			}
		}
	}
	return injected;
}

// --- response side ----------------------------------------------------------

type SseProcessor = (data: string) => void;

function createSseProcessor(): { process: SseProcessor; flush: () => void } {
	// fresh per-response state
	let dirty = false;
	const pendingBySlot = new Map<string, string>(); // slot -> sig awaiting its tool call id
	const idBySlot = new Map<string, string>(); // slot -> tool call id seen so far

	const process = (data: string): void => {
		if (!data || data === "[DONE]") return;
		let chunk: any;
		try {
			chunk = JSON.parse(data);
		} catch {
			return;
		}
		const choices = chunk?.choices;
		if (!Array.isArray(choices)) return;
		for (let ci = 0; ci < choices.length; ci++) {
			// streaming uses delta, non-streaming uses message
			const delta = choices[ci]?.delta ?? choices[ci]?.message;
			const toolCalls = delta?.tool_calls;
			if (!Array.isArray(toolCalls)) continue;
			for (let ti = 0; ti < toolCalls.length; ti++) {
				const tc: ToolCallLike = toolCalls[ti];
				if (!tc || typeof tc !== "object") continue;
				const slot = `${ci}:${tc.index ?? ti}`;
				const sig = tc.extra_content?.google?.thought_signature;
				if (typeof tc.id === "string" && tc.id) {
					idBySlot.set(slot, tc.id);
					if (typeof sig === "string" && !store.has(tc.id)) {
						store.set(tc.id, sig);
						dirty = true;
					}
					const awaited = pendingBySlot.get(slot);
					if (typeof awaited === "string" && !store.has(tc.id)) {
						store.set(tc.id, awaited);
						dirty = true;
						pendingBySlot.delete(slot);
					}
				} else if (typeof sig === "string") {
					const id = idBySlot.get(slot);
					if (id && !store.has(id)) {
						store.set(id, sig);
						dirty = true;
					} else if (!id) {
						pendingBySlot.set(slot, sig);
					}
				}
			}
		}
	};

	const flush = (): void => {
		if (dirty) persist();
	};

	return { process, flush };
}

function wrapResponse(res: Response): Response {
	const decoder = new TextDecoder();
	const { process, flush } = createSseProcessor();
	let buffer = "";

	const tapped = res.body!.pipeThrough(
		new TransformStream({
			transform(chunk: Uint8Array, controller) {
				controller.enqueue(chunk); // pass through untouched, no added latency
				buffer += decoder.decode(chunk, { stream: true });
				let idx: number;
				while ((idx = buffer.indexOf("\n")) >= 0) {
					const line = buffer.slice(0, idx).trim();
					buffer = buffer.slice(idx + 1);
					if (line.startsWith("data:")) process(line.slice(5).trim());
				}
			},
			flush() {
				const rest = buffer.trim();
				if (rest.startsWith("data:")) process(rest.slice(5).trim());
				decoder.decode(); // emit any final buffered bytes
				flush();
			},
		}),
	);

	const headers = new Headers(res.headers);
	headers.delete("content-length");
	return new Response(tapped, { status: res.status, statusText: res.statusText, headers });
}

// --- fetch patch ------------------------------------------------------------

const originalFetch = globalThis.fetch;

async function patchedFetch(input: any, init?: any): Promise<Response> {
	let outInput: any = input;
	let outInit: any = init;
	let tap = false;
	try {
		const url: string =
			typeof input === "string"
				? input
				: input instanceof URL
					? input.href
					: (input as Request)?.url ?? "";
		const method = String(init?.method ?? (input as Request)?.method ?? "GET").toUpperCase();
		if (method === "POST" && url.includes(PROXY_HOST) && url.includes(CHAT_PATH)) {
			let bodyText: string | undefined;
			if (typeof init?.body === "string") {
				bodyText = init.body;
			} else if (init?.body == null && typeof Request !== "undefined" && input instanceof Request) {
				bodyText = await input.clone().text();
			}
			if (bodyText) {
				let body: any = null;
				try {
					body = JSON.parse(bodyText);
				} catch {
					// not JSON; pass through
				}
				if (body && typeof body.model === "string" && MODEL_RE.test(body.model)) {
					const injected = injectSignatures(body);
					if (injected > 0) {
						const headers = new Headers(
							init?.headers ?? (typeof Request !== "undefined" && input instanceof Request ? input.headers : undefined),
						);
						headers.delete("content-length");
						outInit = { ...init, headers, body: JSON.stringify(body) };
						outInput = typeof input === "string" || input instanceof URL ? input : url;
					}
					tap = true;
				}
			}
		}
	} catch {
		// any mistake here must not break the request; fall through with original args
	}

	const res = await originalFetch.call(globalThis, outInput, outInit);
	if (tap && res.ok && res.body) {
		try {
			return wrapResponse(res);
		} catch {
			return res;
		}
	}
	return res;
}

export default function (pi: ExtensionAPI): void {
	// Patch once per process: /reload re-runs this factory and would otherwise
	// chain wrappers (and leak the old closure each time).
	const g = globalThis as any;
	const GUARD = Symbol.for("pi.geminiThoughtSignatures.patched");
	if (g[GUARD]) return;
	g[GUARD] = true;
	g.fetch = patchedFetch;
}
