/**
 * Copy Prompt Extension
 *
 * Copies the current text in the prompt editor to the system clipboard.
 *
 * Shortcut: ctrl+shift+y
 * Command:  /copy-prompt
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { copyToClipboard } from "@mariozechner/pi-coding-agent";

const SHORTCUT = "ctrl+shift+y";

export default function (pi: ExtensionAPI) {
	const copy = async (ctx: Parameters<Parameters<ExtensionAPI["registerShortcut"]>[1]["handler"]>[0]) => {
		const text = ctx.ui.getEditorText() ?? "";
		if (!text) {
			ctx.ui.notify("Prompt is empty", "warning");
			return;
		}
		try {
			await copyToClipboard(text);
			const preview = text.length > 40 ? `${text.slice(0, 40)}…` : text;
			ctx.ui.notify(`Copied prompt (${text.length} chars): ${preview}`, "info");
		} catch (err) {
			ctx.ui.notify(`Copy failed: ${(err as Error).message}`, "error");
		}
	};

	pi.registerShortcut(SHORTCUT, {
		description: "Copy prompt buffer to clipboard",
		handler: copy,
	});

	pi.registerCommand("copy-prompt", {
		description: "Copy the current prompt buffer to the clipboard",
		handler: async (_args, ctx) => copy(ctx),
	});
}
