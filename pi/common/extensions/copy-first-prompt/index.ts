/**
 * Copy First Prompt Extension
 *
 * Copies the first user prompt of the current thread (branch) to the clipboard.
 *
 * Command: /copy-first-prompt
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { copyToClipboard } from "@earendil-works/pi-coding-agent";

type Content = string | Array<{ type: string; text?: string }>;

function textOf(content: Content): string {
	if (typeof content === "string") return content;
	return content
		.filter((part) => part.type === "text" && part.text)
		.map((part) => part.text)
		.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("copy-first-prompt", {
		description: "Copy the first prompt of the current thread to the clipboard",
		handler: async (_args, ctx) => {
			const entry = ctx.sessionManager
				.getBranch()
				.find((e) => e.type === "message" && e.message.role === "user");
			const text = entry?.type === "message" ? textOf(entry.message.content as Content).trim() : "";
			if (!text) {
				ctx.ui.notify("No prompt in this thread", "warning");
				return;
			}
			try {
				await copyToClipboard(text);
				const preview = text.length > 40 ? `${text.slice(0, 40)}…` : text;
				ctx.ui.notify(`Copied first prompt (${text.length} chars): ${preview}`, "info");
			} catch (err) {
				ctx.ui.notify(`Copy failed: ${(err as Error).message}`, "error");
			}
		},
	});
}
