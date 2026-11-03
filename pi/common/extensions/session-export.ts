import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

type ContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; mimeType?: string }
  | { type: "thinking"; thinking: string }
  | { type: "toolCall"; id: string; name: string; arguments: Record<string, unknown> };

type Message = {
  role: string;
  content: string | ContentBlock[];
};

const toSafeFileTimestamp = (value: string) => value.replace(/[:.]/g, "-");

const slugify = (value: string, maxLength = 60) => {
  const slug = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, maxLength);

  return slug.length > 0 ? slug : "session";
};

const contentToText = (content: string | ContentBlock[]) => {
  if (typeof content === "string") return content;

  const parts: string[] = [];
  for (const block of content) {
    if (block.type === "text") {
      parts.push(block.text);
      continue;
    }
    if (block.type === "image") {
      const mime = block.mimeType ?? "unknown";
      parts.push(`[image: ${mime}]`);
      continue;
    }
  }
  return parts.join("\n\n");
};

const assistantToText = (content: ContentBlock[]) => {
  const textParts: string[] = [];
  const toolCalls: string[] = [];

  for (const block of content) {
    if (block.type === "text") {
      textParts.push(block.text);
      continue;
    }
    if (block.type === "toolCall") {
      toolCalls.push(`- ${block.name} ${JSON.stringify(block.arguments)}`);
      continue;
    }
  }

  if (textParts.length === 0 && toolCalls.length > 0) {
    textParts.push(["Tool calls:", ...toolCalls].join("\n"));
  } else if (toolCalls.length > 0) {
    textParts.push(["\nTool calls:", ...toolCalls].join("\n"));
  }

  return textParts.join("\n\n");
};

const getFirstUserMessageText = (entries: Array<{ type: string; message?: Message }>) => {
  for (const entry of entries) {
    if (entry.type !== "message" || !entry.message) continue;
    const message = entry.message;
    if (message.role !== "user") continue;
    const text = contentToText(message.content).trim();
    if (text) return text;
  }
  return "session";
};

const deriveTitle = (prompt: string, maxWords = 6) => {
  const words = prompt.replace(/\n/g, " ").trim().split(/\s+/).slice(0, maxWords);
  return words.join(" ");
};

export default function (pi: ExtensionAPI) {
  let titleSet = false;

  pi.on("session_start", async (_event, _ctx) => {
    titleSet = Boolean(pi.getSessionName());
  });

  pi.on("input", async (event) => {
    if (titleSet) return;
    const text = event.text.trim();
    if (!text) return;
    pi.setSessionName(deriveTitle(text));
    titleSet = true;
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    const branch = ctx.sessionManager.getBranch();
    const entries = [...branch];

    const lines: string[] = [];
    const now = new Date();
    const sessionId = ctx.sessionManager.getSessionId();
    const sessionFile = ctx.sessionManager.getSessionFile();
    const sessionName = pi.getSessionName();

    lines.push("# pi session export");
    if (sessionName) lines.push(`- Session name: ${sessionName}`);
    lines.push(`- Session ID: ${sessionId}`);
    lines.push(`- Exported at: ${now.toISOString()}`);
    if (sessionFile) lines.push(`- Session file: ${sessionFile}`);
    lines.push("");

    for (const entry of entries) {
      if (entry.type !== "message") continue;
      const message = entry.message as Message;

      if (message.role === "user") {
        const text = contentToText(message.content).trim();
        if (!text) continue;
        lines.push("## User");
        lines.push(text);
        lines.push("");
        continue;
      }

      if (message.role === "assistant") {
        const content = Array.isArray(message.content) ? message.content : [];
        const text = assistantToText(content).trim();
        if (!text) continue;
        lines.push("## Assistant");
        lines.push(text);
        lines.push("");
      }
    }

    const exportDir = path.join(os.homedir(), "session-exports");
    const baseName = sessionName ?? getFirstUserMessageText(entries);
    const slug = slugify(baseName);
    const filename = `${toSafeFileTimestamp(now.toISOString())}_${slug}_${sessionId}.md`;
    const outputPath = path.join(exportDir, filename);

    await fs.mkdir(exportDir, { recursive: true });
    await fs.writeFile(outputPath, lines.join("\n"), "utf8");

    if (ctx.hasUI) {
      ctx.ui.notify(`Session exported: ${outputPath}`, "info");
    }
  });
}
