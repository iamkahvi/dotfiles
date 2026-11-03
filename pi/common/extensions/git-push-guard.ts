import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

const PUSH_PATTERN = /^\s*(git|gt)\s+push\b/;

const isPushCommand = (command: string): boolean => {
  // Split on shell separators to get individual subcommands
  const subcommands = command.split(/&&|\|\||[;\n|]/);
  return subcommands.some((sub) => PUSH_PATTERN.test(sub));
};

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (!isPushCommand(command)) return;

    if (!ctx.hasUI) {
      return { block: true, reason: "git push blocked in non-interactive mode" };
    }

    const ok = await ctx.ui.confirm(
      "git push detected",
      `Allow this push?\n\n${command}`,
    );

    if (!ok) {
      return { block: true, reason: "Push blocked by user" };
    }
  });
}
