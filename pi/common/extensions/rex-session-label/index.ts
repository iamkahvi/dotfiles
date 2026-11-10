import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createHash, randomUUID } from "node:crypto";
import { mkdir, open, readFile, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

interface RecordFile {
  version: 1;
  pid: number;
  token: string;
  previous: string;
  label: string;
}

interface Shared {
  registered: boolean;
  disabled: boolean;
  expected?: string;
  pending?: { session: string; block: string; server: string; stateDir: string; record: RecordFile };
}

const sharedKey = Symbol.for("dotfiles.rex-session-label");
const globals = globalThis as typeof globalThis & { [sharedKey]?: Shared };
const shared = globals[sharedKey] ??= { registered: false, disabled: false };

// Rex has no compare-and-set operation. Each write follows a fresh label read,
// but a concurrent user change between the read and write cannot be detected.
export function createController(options: {
  session: string;
  block: string;
  server: string;
  stateDir: string;
  pid: number;
  run: (args: string[]) => Promise<string>;
  alive: (pid: number) => boolean;
  pending?: RecordFile;
}) {
  const { session, block, server, stateDir, pid, run, alive } = options;
  const key = createHash("sha256").update(JSON.stringify([server, session, block])).digest("hex");
  const path = join(stateDir, `${key}.json`);
  let owned: RecordFile | undefined = options.pending;
  let disabled = false;

  async function readRecord(): Promise<RecordFile | undefined> {
    try {
      const value = JSON.parse(await readFile(path, "utf8"));
      if (value.version !== 1 || !Number.isSafeInteger(value.pid) || value.pid <= 0 ||
          typeof value.token !== "string" || typeof value.previous !== "string" ||
          typeof value.label !== "string") throw new Error("Invalid Rex label record");
      return value;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return undefined;
      throw error;
    }
  }

  async function removeRecord(record: RecordFile) {
    const current = await readRecord();
    if (current?.token === record.token) await unlink(path);
  }

  async function getLabel(): Promise<string> {
    const data = JSON.parse(await run(["api", "call", "-s", session, "session.list_blocks", "{}"]));
    const found = Array.isArray(data.blocks) && data.blocks.find((item: any) => item.block_id === block);
    if (!found || typeof found.label !== "string") throw new Error("Rex block not found");
    return found.label;
  }

  async function setLabel(label: string) {
    await run(["api", "call", "-s", session, "session.set_block_label", JSON.stringify({ block_id: block, label })]);
  }

  return {
    async start(id: string, expected?: string): Promise<void> {
      if (disabled || !id || `pi:${id}`.length > 128) return;
      try {
        await mkdir(stateDir, { recursive: true, mode: 0o700 });
        const label = await getLabel();
        if (expected !== undefined && label !== expected) {
          disabled = true;
          return;
        }
        const old = await readRecord();
        let previous = label;
        if (old) {
          if (alive(old.pid)) return;
          if (label === old.label) previous = old.previous;
          else {
            disabled = true;
            await removeRecord(old);
            return;
          }
          await removeRecord(old);
        }
        const record: RecordFile = { version: 1, pid, token: randomUUID(), previous, label: `pi:${id}` };
        // Exclusive creation prevents another Pi process from claiming this pane.
        const file = await open(path, "wx", 0o600);
        try {
          await file.writeFile(JSON.stringify(record));
        } finally {
          await file.close();
        }
        owned = record;
        // Check again after creating the record, before changing the label.
        if (await getLabel() !== label) {
          disabled = true;
          await removeRecord(record);
          owned = undefined;
          return;
        }
        await setLabel(record.label);
      } catch {
        // Rex, its CLI, or the local state can be unavailable. Leave Pi usable.
      }
    },
    async stop(): Promise<{ disabled: boolean; restored?: string; pending?: RecordFile }> {
      if (!owned) return { disabled };
      try {
        const record = owned;
        const current = await getLabel();
        if (current === record.label) {
          if ((await readRecord())?.token !== record.token) {
            disabled = true;
            owned = undefined;
            return { disabled };
          }
          await setLabel(record.previous);
        } else {
          disabled = true;
        }
        await removeRecord(record);
        owned = undefined;
        return { disabled, restored: disabled ? undefined : record.previous };
      } catch {
        // Retain the record when the result is uncertain, for crash recovery.
      }
      return { disabled, pending: owned };
    },
  };
}

export default function (pi: ExtensionAPI) {
  // The package and the install link can discover the same extension twice.
  if (shared.registered) return;
  shared.registered = true;
  let controller: ReturnType<typeof createController> | undefined;
  let scope: Omit<NonNullable<Shared["pending"]>, "record"> | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let inFlight: Promise<void> | undefined;
  let shuttingDown = false;
  let handoffDisabled = false;
  let restored: string | undefined;

  pi.on("session_start", async (_event, ctx) => {
    const session = process.env.REX_SESSION;
    const block = process.env.REX_BLOCK;
    if (ctx.mode !== "tui" || shared.disabled || !session?.startsWith("session:") || !block?.startsWith("block:")) return;
    const server = process.env.REX_SERVER ?? "default";
    const stateDir = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "pi-rex-session-label");
    scope = { session, block, server, stateDir };
    // Only the runtime that owned this exact pane can hand off its record.
    const pending = shared.pending;
    shared.pending = undefined;
    const handoff = pending && pending.session === session && pending.block === block &&
      pending.server === server && pending.stateDir === stateDir ? pending.record : undefined;
    const active = createController({
      session,
      block,
      server,
      stateDir,
      pending: handoff,
      pid: process.pid,
      alive: (pid) => {
        try { process.kill(pid, 0); return true; }
        catch (error) { return (error as NodeJS.ErrnoException).code !== "ESRCH"; }
      },
      run: async (args) => {
        const result = await pi.exec("rex", ["--autostart=false", "--timeout", "2s", ...args], { timeout: 3000, maxBuffer: 1024 * 1024 });
        if (result.code !== 0 || result.killed || result.truncated) throw new Error("Rex command failed");
        return result.stdout;
      },
    });
    controller = active;
    const expected = shared.expected;
    shared.expected = undefined;
    const id = ctx.sessionManager.getSessionId();
    const attempt = async () => {
      if (handoff && restored === undefined) {
        const result = await active.stop();
        if (result.pending) {
          // Retry after Rex returns, even if no further session switch occurs.
          if (!shuttingDown) timer = setTimeout(() => { inFlight = attempt(); }, 1000);
          return;
        }
        handoffDisabled = result.disabled;
        restored = result.restored;
        if (handoffDisabled || shuttingDown) return;
      }
      if (!shuttingDown) await active.start(id, restored ?? expected);
    };
    inFlight = attempt();
    await inFlight;
  });

  pi.on("session_shutdown", async (event) => {
    shuttingDown = true;
    if (timer) clearTimeout(timer);
    // Do not let an old runtime write a label after its replacement starts.
    await inFlight;
    const result = await controller?.stop();
    // Preserve user changes across /new, /resume, /fork, and /reload.
    shared.disabled = event.reason !== "quit" && (handoffDisabled || !!result?.disabled);
    shared.expected = event.reason === "quit" ? undefined : result?.restored ?? restored;
    shared.pending = event.reason !== "quit" && result?.pending && scope
      ? { ...scope, record: result.pending } : undefined;
    shared.registered = false;
  });
}
