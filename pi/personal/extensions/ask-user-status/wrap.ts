import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function questionText(params: any): string {
  const question = Array.isArray(params?.questions)
    ? params.questions[0]?.question
    : params?.question;
  return typeof question === "string" && question.trim() ? question : "User response required";
}

/** Preserve the upstream tool and add Pi's native blocked status to its custom UI. */
export function wrapAskExtension(pi: ExtensionAPI): ExtensionAPI {
  return new Proxy(pi, {
    get(target, key, receiver) {
      if (key !== "registerTool") return Reflect.get(target, key, receiver);
      return (tool: any) => {
        if (tool.name !== "ask_user") return target.registerTool(tool);
        const execute = tool.execute;
        target.registerTool({
          ...tool,
          execute(id: any, params: any, signal: any, onUpdate: any, ctx: any) {
            if (!ctx.ui) return execute.call(tool, id, params, signal, onUpdate, ctx);
            const ui = new Proxy(ctx.ui, {
              get(uiTarget, uiKey, uiReceiver) {
                if (uiKey !== "custom") return Reflect.get(uiTarget, uiKey, uiReceiver);
                return (factory: any, options: any) => uiTarget.custom(factory, {
                  ...options,
                  blocked: options?.blocked ?? { kind: "question", message: questionText(params) },
                });
              },
            });
            const wrappedContext = new Proxy(ctx, {
              get(contextTarget, contextKey, contextReceiver) {
                return contextKey === "ui" ? ui : Reflect.get(contextTarget, contextKey, contextReceiver);
              },
            });
            return execute.call(tool, id, params, signal, onUpdate, wrappedContext);
          },
        });
      };
    },
  });
}
