/**
 * Rex Program Resume (OSC 7577) Extension
 *
 * Reports `pi --session <uuid>` and `cwd` to Rex (or any OSC 7577 terminal)
 * so the terminal restores open pi sessions after a restart or reboot.
 *
 * Security:
 * - Reads `OSC7577_TOKEN` once into process memory and deletes it from
 *   `process.env` so child processes cannot forge resume records.
 * - Never writes `OSC7577_TOKEN` to disk, logs, or the terminal.
 * - Sends `clear=1` only on explicit user quit, never on SIGTERM/SIGHUP.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createHash } from "node:crypto";
import { closeSync, openSync, writeSync } from "node:fs";
import { isAbsolute } from "node:path";

interface ResumeReport {
	sessionId: string;
	cwd: string;
}

interface SharedState {
	token?: string;
	signalsInstalled: boolean;
	exitedBySignal: boolean;
	reported: boolean;
	lastReport?: ResumeReport;
}

const STATE_KEY = Symbol.for("dotfiles.rex-program-resume");
const globals = globalThis as typeof globalThis & { [STATE_KEY]?: SharedState };

function getState(): SharedState {
	let state = globals[STATE_KEY];
	if (!state) {
		const envToken = process.env.OSC7577_TOKEN;
		// Remove immediately so tools, bash calls, and subagents never inherit the token.
		delete process.env.OSC7577_TOKEN;
		state = {
			token: envToken && envToken.length > 0 ? envToken : undefined,
			signalsInstalled: false,
			exitedBySignal: false,
			reported: false,
		};
		globals[STATE_KEY] = state;
	}
	return state;
}

// Capture and strip the token at module load time before any child process spawns.
getState();

function hasControlChars(text: string): boolean {
	for (let i = 0; i < text.length; i++) {
		const code = text.charCodeAt(i);
		if (code <= 0x1f || (code >= 0x7f && code <= 0x9f)) return true;
	}
	return false;
}

function encodeBase64(text: string): string {
	return Buffer.from(text, "utf8").toString("base64");
}

function writeOsc7577(body: string, token: string): boolean {
	const mac = createHash("sha256").update(`${body}:${token}`, "utf8").digest("hex");
	const seq = `\x1b]7577;${body}:mac=${mac}\x1b\\`;
	let fd: number | undefined;
	try {
		fd = openSync("/dev/tty", "w");
		writeSync(fd, seq, undefined, "utf8");
		return true;
	} catch {
		return false;
	} finally {
		if (fd !== undefined) {
			try {
				closeSync(fd);
			} catch {
				// Ignore close errors on a detached tty.
			}
		}
	}
}

function sendResume(state: SharedState, report: ResumeReport): void {
	if (!state.token) return;
	if (!report.sessionId || hasControlChars(report.sessionId)) return;
	const argv = ["pi", "--session", report.sessionId];
	const encodedArgv = argv.map(encodeBase64).join(",");
	const now = Math.floor(Date.now() / 1000);
	let body = `pid=${process.pid}:time=${now}:argv=${encodedArgv}`;
	if (report.cwd && isAbsolute(report.cwd) && !hasControlChars(report.cwd)) {
		body += `:cwd=${encodeBase64(report.cwd)}`;
	}
	if (writeOsc7577(body, state.token)) {
		state.reported = true;
		state.lastReport = report;
	}
}

function sendClear(state: SharedState): void {
	if (!state.token || !state.reported) return;
	const now = Math.floor(Date.now() / 1000);
	const body = `pid=${process.pid}:time=${now}:clear=1`;
	writeOsc7577(body, state.token);
	state.reported = false;
	state.lastReport = undefined;
}

function installSignalListeners(state: SharedState): void {
	if (state.signalsInstalled) return;
	state.signalsInstalled = true;

	const markSignalExit = () => {
		state.exitedBySignal = true;
	};
	// Prepend so our flag is set before Pi's own SIGTERM/SIGHUP handler triggers session_shutdown.
	process.prependListener("SIGTERM", markSignalExit);
	process.prependListener("SIGHUP", markSignalExit);

	// Re-report after Ctrl+Z / fg resume, per OSC 7577 guidance.
	process.on("SIGCONT", () => {
		if (state.lastReport && !state.exitedBySignal) {
			sendResume(state, state.lastReport);
		}
	});
}

export default function (pi: ExtensionAPI) {
	const state = getState();
	if (!state.token) return;

	installSignalListeners(state);

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		const sessionFile = ctx.sessionManager.getSessionFile();
		const sessionId = ctx.sessionManager.getSessionId();
		if (!sessionFile || !sessionId) {
			sendClear(state);
			return;
		}
		sendResume(state, { sessionId, cwd: ctx.cwd });
	});

	pi.on("session_shutdown", async (event) => {
		if (event.reason === "quit" && !state.exitedBySignal) {
			sendClear(state);
		}
	});
}
