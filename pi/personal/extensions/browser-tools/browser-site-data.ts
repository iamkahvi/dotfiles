import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { scanSessionStorage } from "./browser-session-storage";

type SiteOrigin = { origin: string; isPartitioned: boolean; numCookies: number; usage: number };
type SiteGroup = { etldPlus1: string; groupingKey: string; origins: SiteOrigin[] };
type Cookie = { domain: string };

function hostname(value: string): string | undefined {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:" ? url.hostname.toLowerCase() : undefined;
  } catch {
    return undefined;
  }
}

function matches(host: string, domain: string): boolean {
  return host === domain || host.endsWith(`.${domain}`);
}

export function registerBrowserSiteData(pi: ExtensionAPI): void {
  pi.registerCommand("browser-data", {
    description: "Inspect and optionally clear a domain's cookies and site storage",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) return;
      const stateDir = process.env.PI_BROWSER_STATE_DIR ?? join(homedir(), ".pi/agent/state/browser");
      let browser: any;
      let settingsPage: any;
      let cdp: any;
      try {
        let endpoint: { httpEndpoint: string; wsEndpoint: string };
        try {
          endpoint = JSON.parse(await readFile(join(stateDir, "endpoint.json"), "utf8"));
        } catch {
          ctx.ui.notify("Browser is not running. Use a browser tool first, then retry /browser-data.", "warning");
          return;
        }
        // Resolve Playwright from the managed browser package, not from this dotfiles checkout.
        const require = createRequire(import.meta.url);
        const browserRequire = createRequire(require.resolve("pi-browser-tools/package.json"));
        const { chromium } = browserRequire("playwright");
        browser = await chromium.connectOverCDP(endpoint.httpEndpoint, { noDefaults: true });
        const context = browser.contexts()[0];
        if (!context) throw new Error("Shared Chromium has no default context");
        cdp = await browser.newBrowserCDPSession();
        settingsPage = await context.newPage();
        const pageSession = await context.newCDPSession(settingsPage);
        let contextId: string;
        try {
          contextId = (await pageSession.send("Target.getTargetInfo")).targetInfo.browserContextId;
          if (!contextId) throw new Error("Cannot identify the shared browser context");
        } finally {
          await pageSession.detach();
        }
        await settingsPage.goto("chrome://settings/content/all", { waitUntil: "domcontentloaded", timeout: 15_000 });
        const siteList = settingsPage.locator("all-sites");
        await siteList.waitFor({ state: "attached", timeout: 15_000 });
        await siteList.evaluate(async (element: any) => {
          const deadline = Date.now() + 15_000;
          while (!element.browserProxy && Date.now() < deadline) {
            await new Promise((resolve) => setTimeout(resolve, 50));
          }
          if (!element.browserProxy) throw new Error("Chrome site-data UI did not initialize");
        });

        const inventory = async (): Promise<{ groups: SiteGroup[]; cookies: Cookie[] }> => {
          const groups = await siteList.evaluate(async (element: any) => {
            // Chrome's All Sites model includes inactive and partitioned site storage.
            let timer: ReturnType<typeof setTimeout>;
            try {
              const storage = new Promise<SiteGroup[]>((resolve) => {
                element.addWebUiListener("onStorageListFetched", resolve);
              });
              const timeout = new Promise<never>((_, reject) => {
                timer = setTimeout(() => reject(new Error("Timed out reading Chrome site data")), 15_000);
              });
              const [, sites] = await Promise.race([
                Promise.all([element.browserProxy.getAllSites(), storage]),
                timeout,
              ]);
              return sites;
            } finally {
              clearTimeout(timer!);
            }
          });
          // Discard values immediately; only domain metadata is used or displayed.
          const cookies = (await cdp.send("Storage.getCookies")).cookies.map((cookie: Cookie) => ({ domain: cookie.domain }));
          return { groups, cookies };
        };

        const initial = await inventory();
        const initialFrames = await scanSessionStorage(endpoint.wsEndpoint, contextId);
        if (initialFrames.failures) ctx.ui.notify(`Could not inspect ${initialFrames.failures} active browser targets or frames.`, "warning");
        const domains = new Set<string>(initialFrames.hosts);
        for (const group of initial.groups) {
          if (group.etldPlus1) domains.add(group.etldPlus1.toLowerCase());
          for (const item of group.origins) {
            const host = hostname(item.origin);
            if (host) domains.add(host);
          }
        }
        for (const cookie of initial.cookies) domains.add(cookie.domain.replace(/^\./, "").toLowerCase());
        if (!domains.size) {
          ctx.ui.notify("No cookies, site data, or active HTTP(S) sites found.", "info");
          return;
        }
        const domain = await ctx.ui.select("Inspect domain and subdomains", [...domains].sort());
        if (!domain) return;

        const selectData = (data: { groups: SiteGroup[]; cookies: Cookie[] }) => {
          const selected = data.groups.flatMap((group) => group.origins
            .filter((item) => { const host = hostname(item.origin); return host && matches(host, domain); })
            .map((item) => ({ ...item, groupingKey: group.groupingKey })));
          const cookies = data.cookies.filter((cookie) => matches(cookie.domain.replace(/^\./, "").toLowerCase(), domain));
          const ancestors = data.cookies.filter((cookie) => {
            const host = cookie.domain.replace(/^\./, "").toLowerCase();
            return cookie.domain.startsWith(".") && host !== domain && matches(domain, host);
          });
          const hosts = [...new Set([domain, ...selected.map((item) => hostname(item.origin)!), ...cookies.map((cookie) => cookie.domain.replace(/^\./, "").toLowerCase())])].sort();
          return { selected, cookies, ancestors, hosts, partitions: selected.filter((item) => item.isPartitioned) };
        };
        const before = selectData(initial);
        const preview = [
          `Domain: ${domain} (including subdomains)`,
          `Matching hosts: ${before.hosts.join(", ")}`,
          `Cookies: ${before.cookies.length}; site-storage entries: ${before.selected.length}; partitioned entries: ${before.partitions.length}.`,
          `Shared parent-domain cookies kept: ${before.ancestors.length}. They can still authenticate this domain.`,
          "Clears matching cookies, site storage, and active frames' session storage. Active pages may recreate data.",
          "Saved passwords are kept. Chrome may reset persistent-storage permission for affected hosts.",
          "HTTP authentication cache and session storage from navigated-away or closed tabs may remain; Chrome's inventory may not cover every storage type.",
        ].join("\n");
        if (!await ctx.ui.confirm("Clear browser data?", preview)) return;

        // Refresh after confirmation so changes made while the dialog was open are included.
        const current = selectData(await inventory());
        const { hosts, partitions } = current;
        // All Sites' per-origin removals preserve unrelated embedded origins.
        // Chromium handles partition keys itself; clearing a whole site group would be too broad.
        await siteList.evaluate((element: any, data: { hosts: string[]; partitions: { origin: string; groupingKey: string }[] }) => {
          for (const item of data.partitions) {
            (window as any).chrome.send("clearPartitionedUsage", [item.origin, item.groupingKey]);
          }
          for (const host of data.hosts) {
            const authority = host.includes(":") && !host.startsWith("[") ? `[${host}]` : host;
            (window as any).chrome.send("clearUnpartitionedUsage", [`http://${authority}/`]);
          }
        }, { hosts, partitions });
        const clearedFrames = await scanSessionStorage(endpoint.wsEndpoint, contextId, domain);
        const frameFailures = clearedFrames.failures;
        // Chrome's internal clearing API is asynchronous and exposes no completion callback.
        // Re-read the model to report remaining data rather than claiming guaranteed deletion.
        await new Promise((resolve) => setTimeout(resolve, 1_000));
        const after = await inventory();
        const remainingCookies = after.cookies.filter((cookie) => matches(cookie.domain.replace(/^\./, "").toLowerCase(), domain)).length;
        const remainingEntries = after.groups.flatMap((group) => group.origins).filter((item) => {
          const host = hostname(item.origin);
          return host && matches(host, domain) && (item.usage > 0 || item.numCookies > 0);
        }).length;
        const remainingAncestors = selectData(after).ancestors.length;
        ctx.ui.notify(`Clear requested for ${domain}. Remaining in Chrome's inventory: ${remainingCookies} matching cookies, ${remainingEntries} storage entries; ${remainingAncestors} shared parent-domain cookies kept. Session-storage inspection failures: ${frameFailures}. HTTP auth and session storage in tab history may remain; active pages may recreate data.`, remainingCookies || remainingEntries || frameFailures || remainingAncestors ? "warning" : "info");
      } catch (error) {
        ctx.ui.notify(`browser-data failed: ${error instanceof Error ? error.message : String(error)}`, "error");
      } finally {
        if (settingsPage) await settingsPage.close().catch(() => {});
        if (cdp) await cdp.detach().catch(() => {});
        if (browser) await browser.close().catch(() => {});
      }
    },
  });
}
