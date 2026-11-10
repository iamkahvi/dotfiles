import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import extension, { createController } from "../index";

const dirs: string[] = [];
afterEach(async () => {
  await Promise.all(dirs.splice(0).map((dir) => rm(dir, { recursive: true, force: true })));
});

async function fixture(initial = "original label") {
  const stateDir = await mkdtemp(join(tmpdir(), "pi-rex-test-"));
  dirs.push(stateDir);
  const state = { label: initial, tab: "Keep this tab", writes: [] as string[], failRead: false, failWrite: false, reads: 0, onRead: undefined as undefined | (() => void) };
  const active = new Set<number>();
  const make = (pid: number) => createController({
    session: "session:test", block: "block:test", server: "server", stateDir, pid,
    alive: (other) => active.has(other),
    run: async (args) => {
      expect(args.slice(0, 4)).toEqual(["api", "call", "-s", "session:test"]);
      if (args[4] === "session.list_blocks") {
        if (state.failRead) throw new Error("offline");
        state.reads++;
        state.onRead?.();
        return JSON.stringify({ blocks: [{ block_id: "block:test", label: state.label }] });
      }
      expect(args[4]).toBe("session.set_block_label");
      if (state.failWrite) throw new Error("offline");
      const params = JSON.parse(args[5]);
      expect(params.block_id).toBe("block:test");
      state.label = params.label;
      state.writes.push(params.label);
      return "{}";
    },
  });
  const record = async () => join(stateDir, (await readdir(stateDir))[0]);
  return { state, active, make, stateDir, record };
}

describe("Rex label ownership", () => {
  test("sets and restores the exact block label without changing the tab", async () => {
    const { state, make, stateDir } = await fixture("a 'label' with spaces");
    const controller = make(101);
    await controller.start("session-id");
    expect(state.label).toBe("pi:session-id");
    expect(await controller.stop()).toEqual({ disabled: false, restored: "a 'label' with spaces" });
    expect(state.label).toBe("a 'label' with spaces");
    expect(state.tab).toBe("Keep this tab");
    expect(await readdir(stateDir)).toEqual([]);
  });

  test.each(["new", "resume", "fork", "reload"])("restores and reacquires on %s", async () => {
    const { state, make } = await fixture();
    const old = make(101);
    await old.start("old");
    await old.stop();
    const next = make(101);
    await next.start("next");
    expect(state.label).toBe("pi:next");
    await next.stop();
    expect(state.label).toBe("original label");
  });

  test("does not restore over a user change, including a change back to the original", async () => {
    for (const label of ["user label", "original label"]) {
      const { state, make } = await fixture();
      const controller = make(101);
      await controller.start("old");
      state.label = label;
      expect((await controller.stop()).disabled).toBe(true);
      expect(state.label).toBe(label);
      await controller.start("new");
      expect(state.label).toBe(label);
    }
  });

  test("preserves a user change before the initial write", async () => {
    const { state, make, stateDir } = await fixture();
    state.onRead = () => { if (state.reads === 2) state.label = "user label"; };
    const controller = make(101);
    await controller.start("first");
    expect(state.label).toBe("user label");
    expect(state.writes).toEqual([]);
    expect((await controller.stop()).disabled).toBe(true);
    expect(await readdir(stateDir)).toEqual([]);
  });

  test("recovers a stale label and restores its original after a crash", async () => {
    const { state, make } = await fixture();
    await make(101).start("crashed");
    const next = make(102);
    await next.start("active");
    expect(state.label).toBe("pi:active");
    await next.stop();
    expect(state.label).toBe("original label");
  });

  test("preserves a user edit after a crash", async () => {
    const { state, make, stateDir } = await fixture();
    await make(101).start("crashed");
    state.label = "user label";
    const next = make(102);
    await next.start("active");
    expect(state.label).toBe("user label");
    expect((await next.stop()).disabled).toBe(true);
    expect(await readdir(stateDir)).toEqual([]);
  });

  test("does not claim a pane owned by a live Pi", async () => {
    const { state, active, make } = await fixture();
    active.add(101);
    const old = make(101);
    await old.start("parent");
    const child = make(102);
    await child.start("child");
    await child.stop();
    expect(state.label).toBe("pi:parent");
    await old.stop();
    expect(state.label).toBe("original label");
  });

  test("fails closed when Rex or the journal is unavailable", async () => {
    const { state, make, record } = await fixture();
    state.failRead = true;
    await make(101).start("first");
    expect(state.writes).toEqual([]);
    state.failRead = false;
    const current = make(101);
    await current.start("first");
    const path = await record();
    await writeFile(path, "invalid JSON");
    await current.stop();
    expect(state.label).toBe("pi:first");
    await make(102).start("second");
    expect(state.label).toBe("pi:first");
  });

  test("retains the journal if restore fails and recovers later", async () => {
    const { state, make, record } = await fixture();
    const current = make(101);
    await current.start("first");
    state.failWrite = true;
    await current.stop();
    expect(JSON.parse(await readFile(await record(), "utf8")).previous).toBe("original label");
    state.failWrite = false;
    const next = make(102);
    await next.start("second");
    await next.stop();
    expect(state.label).toBe("original label");
  });

  test("ignores an invalid session ID", async () => {
    const { state, make } = await fixture();
    const controller = make(101);
    await controller.start("");
    await controller.start("x".repeat(126));
    expect(state.writes).toEqual([]);
  });
});

async function eventFixture() {
  const dir = await mkdtemp(join(tmpdir(), "pi-rex-events-"));
  dirs.push(dir);
  const keys = ["REX_SESSION", "REX_BLOCK", "REX_SERVER", "XDG_CACHE_HOME"] as const;
  const saved = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  process.env.REX_SESSION = "session:test";
  process.env.REX_BLOCK = "block:test";
  process.env.REX_SERVER = "server";
  process.env.XDG_CACHE_HOME = dir;
  const state = {
    label: "original", failRead: false, failWrite: false, writes: [] as string[], reads: 0,
    onRead: undefined as undefined | (() => Promise<void>),
  };
  const context = (id: string) => ({ mode: "tui", sessionManager: { getSessionId: () => id } });
  const runtime = () => {
    const handlers: Record<string, any> = {};
    extension({
      on: (name: string, handler: any) => { handlers[name] = handler; },
      exec: async (_name: string, args: string[]) => {
        if (args.includes("session.list_blocks")) {
          if (state.failRead) throw new Error("offline");
          await state.onRead?.();
          state.reads++;
          return { code: 0, stdout: JSON.stringify({ blocks: [{ block_id: "block:test", label: state.label }] }) };
        }
        if (state.failWrite) throw new Error("offline");
        state.label = JSON.parse(args[args.length - 1]).label;
        state.writes.push(state.label);
        return { code: 0, stdout: "{}" };
      },
    } as any);
    return handlers;
  };
  const cleanup = () => {
    for (const key of keys) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  return { state, context, runtime, cleanup, stateDir: join(dir, "pi-rex-session-label") };
}

async function waitUntil(check: () => boolean | Promise<boolean>) {
  const deadline = Date.now() + 4000;
  while (!(await check()) && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 20));
  expect(await check()).toBe(true);
}

describe("Pi extension", () => {
  test("does nothing outside a Rex TUI and avoids duplicate registration", async () => {
    const handlers: Record<string, any> = {};
    const api = { on: (name: string, handler: any) => { handlers[name] = handler; }, exec: () => { throw new Error("unexpected"); } };
    extension(api as any);
    let calls = 0;
    extension({ on: () => { calls++; } } as any);
    expect(calls).toBe(0);
    const ctx = { mode: "rpc", sessionManager: { getSessionId: () => "id" } };
    await handlers.session_start({ reason: "startup" }, ctx);
    await handlers.session_shutdown({ reason: "quit" }, ctx);
  });

  test("preserves a user edit between Pi runtime instances", async () => {
    const { state, make } = await fixture();
    const first = make(101);
    await first.start("first");
    const result = await first.stop();
    state.label = "user label";
    const second = make(101);
    await second.start("second", result.restored);
    expect(state.label).toBe("user label");
    expect((await second.stop()).disabled).toBe(true);
  });

  test.each(["failRead", "failWrite"] as const)("recovers after a failed restore and two resumes: %s", async (failure) => {
    const { state, context, runtime, cleanup, stateDir } = await eventFixture();
    let current = runtime();
    try {
      await current.session_start({ reason: "startup" }, context("first"));
      state[failure] = true;
      await current.session_shutdown({ reason: "resume" }, context("first"));
      expect(state.label).toBe("pi:first");
      expect(await readdir(stateDir)).toHaveLength(1);

      current = runtime();
      await current.session_start({ reason: "resume" }, context("second"));
      await current.session_shutdown({ reason: "resume" }, context("second"));
      current = runtime();
      await current.session_start({ reason: "resume" }, context("third"));
      expect(state.label).toBe("pi:first");

      state[failure] = false;
      await waitUntil(() => state.label === "pi:third");
      const path = join(stateDir, (await readdir(stateDir))[0]);
      const record = JSON.parse(await readFile(path, "utf8"));
      expect(record.pid).toBe(process.pid);
      expect(record.previous).toBe("original");
      expect(record.label).toBe("pi:third");
      await current.session_shutdown({ reason: "quit" }, context("third"));
      expect(state.label).toBe("original");
      expect(await readdir(stateDir)).toEqual([]);
    } finally {
      await current.session_shutdown({ reason: "quit" }, context("third"));
      cleanup();
    }
  });

  test("recovers at resume when Rex returns before the replacement starts", async () => {
    const { state, context, runtime, cleanup, stateDir } = await eventFixture();
    let current = runtime();
    try {
      await current.session_start({ reason: "startup" }, context("first"));
      state.failRead = true;
      await current.session_shutdown({ reason: "resume" }, context("first"));
      state.failRead = false;
      current = runtime();
      await current.session_start({ reason: "resume" }, context("second"));
      expect(state.label).toBe("pi:second");
      await current.session_shutdown({ reason: "quit" }, context("second"));
      expect(state.label).toBe("original");
      expect(await readdir(stateDir)).toEqual([]);
    } finally {
      await current.session_shutdown({ reason: "quit" }, context("second"));
      cleanup();
    }
  });

  test("waits for a retry in progress before it replaces the runtime", async () => {
    const { state, context, runtime, cleanup } = await eventFixture();
    let current = runtime();
    let release!: () => void;
    let reached = false;
    try {
      await current.session_start({ reason: "startup" }, context("first"));
      state.failRead = true;
      await current.session_shutdown({ reason: "resume" }, context("first"));
      current = runtime();
      await current.session_start({ reason: "resume" }, context("second"));
      state.onRead = () => {
        state.onRead = undefined;
        reached = true;
        return new Promise<void>((resolve) => { release = resolve; });
      };
      state.failRead = false;
      await waitUntil(() => reached);
      const shutdown = current.session_shutdown({ reason: "resume" }, context("second"));
      release();
      await shutdown;
      expect(state.writes).toEqual(["pi:first", "original"]);
      current = runtime();
      await current.session_start({ reason: "resume" }, context("third"));
      expect(state.label).toBe("pi:third");
      await current.session_shutdown({ reason: "quit" }, context("third"));
      expect(state.label).toBe("original");
    } finally {
      release?.();
      await current.session_shutdown({ reason: "quit" }, context("third"));
      cleanup();
    }
  });

  test("does not reclaim a record with a different token", async () => {
    const { state, context, runtime, cleanup, stateDir } = await eventFixture();
    let current = runtime();
    try {
      await current.session_start({ reason: "startup" }, context("first"));
      state.failRead = true;
      await current.session_shutdown({ reason: "resume" }, context("first"));
      const path = join(stateDir, (await readdir(stateDir))[0]);
      const record = JSON.parse(await readFile(path, "utf8"));
      record.token = "another-owner";
      await writeFile(path, JSON.stringify(record));
      current = runtime();
      await current.session_start({ reason: "resume" }, context("second"));
      const reads = state.reads;
      state.failRead = false;
      await waitUntil(() => state.reads > reads);
      await current.session_shutdown({ reason: "resume" }, context("second"));
      current = runtime();
      await current.session_start({ reason: "resume" }, context("third"));
      await current.session_shutdown({ reason: "quit" }, context("third"));
      expect(state.writes).toEqual(["pi:first"]);
      expect(JSON.parse(await readFile(path, "utf8")).token).toBe("another-owner");
    } finally {
      await current.session_shutdown({ reason: "quit" }, context("third"));
      cleanup();
    }
  });

  test.each(["user label", "original"])("preserves a user edit after a failed restore: %s", async (label) => {
    const { state, context, runtime, cleanup, stateDir } = await eventFixture();
    let current = runtime();
    try {
      await current.session_start({ reason: "startup" }, context("first"));
      state.failRead = true;
      await current.session_shutdown({ reason: "resume" }, context("first"));
      current = runtime();
      await current.session_start({ reason: "resume" }, context("second"));
      state.label = label;
      state.failRead = false;
      await waitUntil(async () => (await readdir(stateDir)).length === 0);
      expect(state.label).toBe(label);
      expect(state.writes).toEqual(["pi:first"]);
      await current.session_shutdown({ reason: "resume" }, context("second"));
      current = runtime();
      await current.session_start({ reason: "resume" }, context("third"));
      await current.session_shutdown({ reason: "quit" }, context("third"));
      expect(state.label).toBe(label);
      expect(state.writes).toEqual(["pi:first"]);
    } finally {
      await current.session_shutdown({ reason: "quit" }, context("second"));
      cleanup();
    }
  });

  test("keeps a user label through Pi runtime replacement", async () => {
    const dir = await mkdtemp(join(tmpdir(), "pi-rex-events-"));
    dirs.push(dir);
    const saved = { ...process.env };
    let label = "original";
    try {
      process.env.REX_SESSION = "session:test";
      process.env.REX_BLOCK = "block:test";
      process.env.REX_SERVER = "server";
      process.env.XDG_CACHE_HOME = dir;
      const runtime = () => {
        const handlers: Record<string, any> = {};
        extension({
          on: (name: string, handler: any) => { handlers[name] = handler; },
          exec: async (_name: string, args: string[]) => {
            if (args.includes("session.list_blocks")) {
              return { code: 0, stdout: JSON.stringify({ blocks: [{ block_id: "block:test", label }] }) };
            }
            label = JSON.parse(args[args.length - 1]).label;
            return { code: 0, stdout: "{}" };
          },
        } as any);
        return handlers;
      };
      const context = (id: string) => ({ mode: "tui", sessionManager: { getSessionId: () => id } });
      const first = runtime();
      await first.session_start({ reason: "startup" }, context("first"));
      expect(label).toBe("pi:first");
      label = "user label";
      await first.session_shutdown({ reason: "new" }, context("first"));
      const second = runtime();
      await second.session_start({ reason: "new" }, context("second"));
      await second.session_shutdown({ reason: "quit" }, context("second"));
      expect(label).toBe("user label");
    } finally {
      for (const key of ["REX_SESSION", "REX_BLOCK", "REX_SERVER", "XDG_CACHE_HOME"]) {
        if (saved[key] === undefined) delete process.env[key];
        else process.env[key] = saved[key];
      }
    }
  });
});
