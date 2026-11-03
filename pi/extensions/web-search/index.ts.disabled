import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { truncateHead, DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, formatSize } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Text } from "@mariozechner/pi-tui";

const SEARXNG_URL = process.env.SEARXNG_URL ?? "http://100.88.174.104:8083";

interface SearxResult {
	url: string;
	title: string;
	content: string;
	engines: string[];
	score: number;
	category: string;
	publishedDate?: string | null;
}

interface SearxResponse {
	query: string;
	number_of_results: number;
	results: SearxResult[];
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Search the web using SearXNG metasearch engine. Returns titles, URLs, and snippets. Use this to find current information, documentation, answers to questions, etc.",
		parameters: Type.Object({
			query: Type.String({ description: "Search query" }),
			num_results: Type.Optional(
				Type.Number({ description: "Max results to return (default: 10, max: 30)", default: 10 })
			),
			categories: Type.Optional(
				Type.String({
					description: 'Comma-separated categories to search (e.g. "general", "images", "news", "it", "science"). Default: general',
				})
			),
		}),

		async execute(toolCallId, params, signal) {
			const numResults = Math.min(params.num_results ?? 10, 30);
			const categories = params.categories ?? "general";

			const searchParams = new URLSearchParams({
				q: params.query,
				format: "json",
				categories,
			});

			try {
				const response = await fetch(`${SEARXNG_URL}/search?${searchParams.toString()}`, {
					signal,
				});

				if (!response.ok) {
					return {
						content: [{ type: "text", text: `Search request failed: HTTP ${response.status}` }],
						isError: true,
						details: {},
					};
				}

				const data = (await response.json()) as SearxResponse;
				const results = data.results.slice(0, numResults);

				if (results.length === 0) {
					return {
						content: [{ type: "text", text: `No results found for "${params.query}"` }],
						details: { query: params.query, count: 0 },
					};
				}

				const formatted = results
					.map((r, i) => {
						let entry = `${i + 1}. ${r.title}\n   ${r.url}`;
						if (r.content) entry += `\n   ${r.content}`;
						if (r.publishedDate) entry += `\n   Published: ${r.publishedDate}`;
						if (r.engines?.length) entry += `\n   Sources: ${r.engines.join(", ")}`;
						return entry;
					})
					.join("\n\n");

				const output = `Search results for "${params.query}" (${results.length} results):\n\n${formatted}`;

				const truncation = truncateHead(output, {
					maxLines: DEFAULT_MAX_LINES,
					maxBytes: DEFAULT_MAX_BYTES,
				});

				return {
					content: [{ type: "text", text: truncation.content }],
					details: { query: params.query, count: results.length },
				};
			} catch (err: any) {
				return {
					content: [{ type: "text", text: `Search failed: ${err.message}` }],
					isError: true,
					details: {},
				};
			}
		},

		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("web_search "));
			text += theme.fg("muted", `"${args.query}"`);
			if (args.categories && args.categories !== "general") {
				text += theme.fg("dim", ` [${args.categories}]`);
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			if (result.isError) {
				const errText = result.content?.find((c: any) => c.type === "text")?.text ?? "Unknown error";
				return new Text(theme.fg("error", errText), 0, 0);
			}

			const details = result.details as { query: string; count: number } | undefined;
			let text = theme.fg("success", `${details?.count ?? 0} results`);

			if (expanded) {
				const content = result.content?.find((c: any) => c.type === "text")?.text ?? "";
				text += "\n" + theme.fg("dim", content);
			}

			return new Text(text, 0, 0);
		},
	});
}
