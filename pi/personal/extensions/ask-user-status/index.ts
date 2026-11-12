import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";
import { wrapAskExtension } from "./wrap.ts";

export default async function (pi: ExtensionAPI) {
  const path = join(getAgentDir(), "npm", "node_modules", "pi-ask-user", "index.ts");
  const upstream = await import(path);
  await upstream.default(wrapAskExtension(pi));
}
