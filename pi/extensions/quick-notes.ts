import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

type NotesState = {
  notes: string[];
};

const TOOL_NAMES = new Set(["add_note", "list_notes", "clear_notes"]);

export default function (pi: ExtensionAPI) {
  let state: NotesState = { notes: [] };

  const setNotesWidget = (notes: string[], ctx: { ui: any; hasUI: boolean }) => {
    if (!ctx.hasUI) return;
    if (notes.length === 0) {
      ctx.ui.setWidget("quick-notes", undefined);
      return;
    }
    const lines = ["Notes:"].concat(notes.map((note, i) => `  ${i + 1}. ${note}`));
    ctx.ui.setWidget("quick-notes", lines);
  };

  pi.on("session_start", async (_event, ctx) => {
    state = { notes: [] };
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const message = entry.message;
      if (message.role !== "toolResult") continue;
      if (!TOOL_NAMES.has(message.toolName)) continue;
      const notes = message.details?.notes;
      if (Array.isArray(notes)) {
        state.notes = [...notes];
      }
    }
    setNotesWidget(state.notes, ctx);
  });

  pi.registerTool({
    name: "add_note",
    label: "Add Note",
    description: "Add a short note to the session-local notes list.",
    parameters: Type.Object({
      text: Type.String({ description: "Note text" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      state.notes = [...state.notes, params.text.trim()].filter(Boolean);
      setNotesWidget(state.notes, ctx);
      return {
        content: [
          {
            type: "text",
            text: `Added note #${state.notes.length}.`,
          },
        ],
        details: { notes: [...state.notes] },
      };
    },
  });

  pi.registerTool({
    name: "list_notes",
    label: "List Notes",
    description: "List current notes from the session-local notes list.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      const text =
        state.notes.length === 0
          ? "No notes yet."
          : state.notes.map((note, i) => `${i + 1}. ${note}`).join("\n");
      setNotesWidget(state.notes, ctx);
      return {
        content: [{ type: "text", text }],
        details: { notes: [...state.notes] },
      };
    },
  });

  pi.registerTool({
    name: "clear_notes",
    label: "Clear Notes",
    description: "Clear all notes from the session-local notes list.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      state.notes = [];
      setNotesWidget(state.notes, ctx);
      return {
        content: [{ type: "text", text: "Cleared notes." }],
        details: { notes: [] },
      };
    },
  });

  pi.registerCommand("notes", {
    description: "Show current notes in a widget and notification.",
    handler: async (_args, ctx) => {
      const summary =
        state.notes.length === 0
          ? "No notes yet."
          : `${state.notes.length} notes.`;
      if (ctx.hasUI) {
        ctx.ui.notify(summary, "info");
        setNotesWidget(state.notes, ctx);
      }
    },
  });
}
