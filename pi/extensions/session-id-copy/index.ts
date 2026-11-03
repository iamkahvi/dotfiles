/**
 * Session ID Extension
 *
 * When an interactive session starts, shows the session ID. Skips reloads and
 * non-TUI modes (print, json, rpc).
 *
 * Command: /copy-session-id  copies the current session ID to the clipboard
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { copyToClipboard } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (event, ctx) => {
		if (event.reason === "reload" || ctx.mode !== "tui") return;
		ctx.ui.notify(`Session ${ctx.sessionManager.getSessionId()}`, "info");
	});

	pi.registerCommand("copy-session-id", {
		description: "Copy the current session ID to the clipboard",
		handler: async (_args, ctx) => {
			const id = ctx.sessionManager.getSessionId();
			try {
				await copyToClipboard(id);
				ctx.ui.notify(`Copied session ${id}`, "info");
			} catch (err) {
				ctx.ui.notify(`Copy failed: ${(err as Error).message}`, "error");
			}
		},
	});
}
