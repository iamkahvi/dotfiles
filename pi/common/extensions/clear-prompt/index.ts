/**
 * Clear Prompt Extension
 *
 * Empties the prompt editor.
 *
 * Shortcut: ctrl+shift+backspace
 * Command:  /clear-prompt
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const SHORTCUT = "ctrl+shift+backspace";

export default function (pi: ExtensionAPI) {
	const clear = (ctx: Parameters<Parameters<ExtensionAPI["registerShortcut"]>[1]["handler"]>[0]) => {
		const text = ctx.ui.getEditorText() ?? "";
		if (!text) return;
		ctx.ui.setEditorText("");
	};

	pi.registerShortcut(SHORTCUT, {
		description: "Clear prompt buffer",
		handler: async (ctx) => clear(ctx),
	});

	pi.registerCommand("clear-prompt", {
		description: "Clear the current prompt buffer",
		handler: async (_args, ctx) => clear(ctx),
	});
}
