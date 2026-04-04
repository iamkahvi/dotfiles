import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
	truncateHead,
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
} from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Text } from "@mariozechner/pi-tui";

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "url_to_markdown",
		label: "URL to Markdown",
		description:
			"Fetch a URL and extract its main content as clean markdown. Uses defuddle to strip navigation, ads, and boilerplate. Good for reading articles, documentation, blog posts, etc.",
		parameters: Type.Object({
			url: Type.String({ description: "URL to fetch and convert to markdown" }),
		}),

		async execute(toolCallId, params, signal) {
			const url = params.url.replace(/^@/, "");

			try {
				const result = await pi.exec("npx", ["defuddle", "parse", "--markdown", url], {
					signal,
					timeout: 30000,
				});

				if (result.code !== 0) {
					const errMsg = result.stderr?.trim() || result.stdout?.trim() || "Unknown error";
					return {
						content: [{ type: "text", text: `Failed to fetch/parse ${url}: ${errMsg}` }],
						isError: true,
						details: { url },
					};
				}

				const markdown = result.stdout?.trim();
				if (!markdown) {
					return {
						content: [{ type: "text", text: `No content extracted from ${url}` }],
						isError: true,
						details: { url },
					};
				}

				const truncation = truncateHead(markdown, {
					maxLines: DEFAULT_MAX_LINES,
					maxBytes: DEFAULT_MAX_BYTES,
				});

				let output = truncation.content;
				if (truncation.truncated) {
					output += `\n\n[Content truncated: ${truncation.outputLines} of ${truncation.totalLines} lines`;
					output += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)})]`;
				}

				return {
					content: [{ type: "text", text: output }],
					details: {
						url,
						truncated: truncation.truncated,
						totalLines: truncation.totalLines,
						totalBytes: truncation.totalBytes,
					},
				};
			} catch (err: any) {
				return {
					content: [{ type: "text", text: `Failed to process ${url}: ${err.message}` }],
					isError: true,
					details: { url },
				};
			}
		},

		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("url_to_markdown "));
			text += theme.fg("muted", args.url);
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			if (result.isError) {
				const errText = result.content?.find((c: any) => c.type === "text")?.text ?? "Unknown error";
				return new Text(theme.fg("error", errText), 0, 0);
			}

			const details = result.details as { url: string; truncated: boolean; totalLines: number; totalBytes: number } | undefined;
			let text = theme.fg("success", "Content extracted");
			if (details) {
				text += theme.fg("dim", ` (${details.totalLines} lines, ${formatSize(details.totalBytes)})`);
				if (details.truncated) {
					text += theme.fg("warning", " [truncated]");
				}
			}

			if (expanded) {
				const content = result.content?.find((c: any) => c.type === "text")?.text ?? "";
				// Show first ~40 lines in collapsed-ish preview
				const preview = content.split("\n").slice(0, 40).join("\n");
				text += "\n" + theme.fg("dim", preview);
				if (content.split("\n").length > 40) {
					text += "\n" + theme.fg("dim", "...");
				}
			}

			return new Text(text, 0, 0);
		},
	});
}
