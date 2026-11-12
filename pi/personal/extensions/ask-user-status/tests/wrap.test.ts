import { describe, expect, test } from "bun:test";
import { wrapAskExtension } from "../wrap";

function fixture() {
  const registered: any[] = [];
  const pi: any = { registerTool: (tool: any) => registered.push(tool), marker: 7 };
  return { registered, wrapped: wrapAskExtension(pi) };
}

describe("ask status wrapper", () => {
  test("keeps other tools and API properties intact", () => {
    const { registered, wrapped } = fixture();
    const tool = { name: "other", execute: () => 1 };
    wrapped.registerTool(tool as any);
    expect(registered[0]).toBe(tool);
    expect((wrapped as any).marker).toBe(7);
  });

  test.each(["overlay", "inline"])("adds question status to %s custom UI", async (mode) => {
    const { registered, wrapped } = fixture();
    const factory = () => {};
    const onHandle = () => {};
    const options = mode === "overlay" ? { overlay: true, onHandle } : undefined;
    const signal = new AbortController().signal;
    const update = () => {};
    let seen: any;
    wrapped.registerTool({
      name: "ask_user",
      execute: (id: any, params: any, actualSignal: any, actualUpdate: any, ctx: any) => {
        expect([id, params.question, actualSignal, actualUpdate]).toEqual(["id", "Choose one?", signal, update]);
        expect(ctx.marker).toBe(4);
        return ctx.ui.custom(factory, options);
      },
    } as any);
    const ctx = { marker: 4, ui: { custom: (f: any, o: any) => { seen = [f, o]; return "answer"; } } };
    expect(await registered[0].execute("id", { question: "Choose one?" }, signal, update, ctx)).toBe("answer");
    expect(seen).toEqual([factory, { ...options, blocked: { kind: "question", message: "Choose one?" } }]);
  });

  test("uses the first batch question and preserves an upstream blocked option", async () => {
    const { registered, wrapped } = fixture();
    wrapped.registerTool({ name: "ask_user", execute: (_id: any, _params: any, _signal: any, _update: any, ctx: any) => ctx.ui.custom(() => {}, ctx.options) } as any);
    let options: any;
    const ctx = { options: undefined as any, ui: { custom: (_factory: any, opts: any) => { options = opts; } } };
    const params = { question: "Heading", questions: [{ question: "First?" }, { question: "Second?" }] };
    await registered[0].execute("id", params, undefined, undefined, ctx);
    expect(options.blocked).toEqual({ kind: "question", message: "First?" });
    ctx.options = { blocked: { kind: "permission", message: "Upstream" } };
    await registered[0].execute("id", params, undefined, undefined, ctx);
    expect(options.blocked).toEqual(ctx.options.blocked);
  });

  test("leaves a missing UI and errors to the upstream tool", async () => {
    const { registered, wrapped } = fixture();
    wrapped.registerTool({ name: "ask_user", execute: (_id: any, _params: any, _signal: any, _update: any, ctx: any) => {
      expect(ctx.ui).toBeUndefined();
      throw new Error("no UI");
    } } as any);
    expect(() => registered[0].execute("id", {}, undefined, undefined, {})).toThrow("no UI");
  });
});
