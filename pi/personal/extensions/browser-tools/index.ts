import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerBrowserSiteData } from "./browser-site-data";

// Load the installed package without forking it. Only change its flag default.
export default async function (pi: ExtensionAPI) {
  const require = createRequire(import.meta.url);
  const path = join(dirname(require.resolve("pi-browser-tools/package.json")), "src/index.ts");
  const { default: browserTools } = await import(path);

  browserTools(new Proxy(pi, {
    get(target, property, receiver) {
      if (property === "registerFlag") {
        return (name: string, options: Parameters<ExtensionAPI["registerFlag"]>[1]) => {
          target.registerFlag(name, name === "browser-headless" ? { ...options, default: true } : options);
        };
      }
      return Reflect.get(target, property, receiver);
    },
  }));
  registerBrowserSiteData(pi);
}
