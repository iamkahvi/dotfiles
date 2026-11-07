type TargetInfo = {
  targetId: string;
  type: string;
  browserContextId?: string;
};

type Frame = {
  id: string;
  url: string;
};

type FrameTree = {
  frame?: Frame;
  childFrames?: FrameTree[];
};

type CdpReply = {
  id?: number;
  result?: any;
  error?: { message?: string };
};

type PendingRequest = {
  resolve: (result: any) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

const CDP_TIMEOUT_MS = 10_000;
let isolatedWorldSequence = 0;

class CdpConnection {
  private nextId = 0;
  private pending = new Map<number, PendingRequest>();

  constructor(private readonly socket: WebSocket) {
    socket.addEventListener("message", this.onMessage);
    socket.addEventListener("error", this.onSocketError);
    socket.addEventListener("close", this.onSocketClose);
  }

  request(method: string, params: Record<string, unknown> = {}, sessionId?: string): Promise<any> {
    if (this.socket.readyState !== WebSocket.OPEN) {
      return Promise.reject(new Error("CDP WebSocket is not open"));
    }

    const id = ++this.nextId;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP ${method} timed out`));
      }, CDP_TIMEOUT_MS);
      this.pending.set(id, { resolve, reject, timer });
      try {
        this.socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
      } catch {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(new Error(`Could not send CDP ${method}`));
      }
    });
  }

  private onMessage = (event: MessageEvent): void => {
    let reply: CdpReply;
    try {
      reply = JSON.parse(String(event.data));
    } catch {
      return;
    }
    if (typeof reply.id !== "number") return;
    const pending = this.pending.get(reply.id);
    if (!pending) return;
    this.pending.delete(reply.id);
    clearTimeout(pending.timer);
    if (reply.error) pending.reject(new Error(reply.error.message ?? "CDP command failed"));
    else pending.resolve(reply.result);
  };

  private onSocketError = (): void => {
    this.rejectPending("CDP WebSocket error");
  };

  private onSocketClose = (): void => {
    this.rejectPending("CDP WebSocket closed");
  };

  private rejectPending(message: string): void {
    for (const [id, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(new Error(message));
      this.pending.delete(id);
    }
  }
}

function isHttpUrl(value: string): boolean {
  try {
    const protocol = new URL(value).protocol;
    return protocol === "http:" || protocol === "https:";
  } catch {
    return false;
  }
}

function normalizeDomain(value: string): string {
  const input = value.trim();
  if (!input || /[\\/?#@\s]/.test(input)) throw new TypeError("domain must be a hostname");
  if (input.startsWith("[") ? !/^\[[0-9a-f:.]+\]$/i.test(input) : input.includes(":")) {
    throw new TypeError("domain must not include a port");
  }

  try {
    const url = new URL(`http://${input}/`);
    const hostname = url.hostname.toLowerCase().replace(/\.$/, "");
    if (url.port || !hostname || hostname.startsWith(".")) throw new TypeError("invalid hostname");
    return hostname;
  } catch {
    throw new TypeError("domain must be a valid hostname without a port");
  }
}

async function connect(socket: WebSocket): Promise<void> {
  if (socket.readyState === WebSocket.OPEN) return;
  if (socket.readyState === WebSocket.CLOSED) throw new Error("CDP WebSocket closed before connecting");

  await new Promise<void>((resolve, reject) => {
    const cleanup = (): void => {
      clearTimeout(timer);
      socket.removeEventListener("open", onOpen);
      socket.removeEventListener("error", onError);
      socket.removeEventListener("close", onClose);
    };
    const onOpen = (): void => { cleanup(); resolve(); };
    const onError = (): void => { cleanup(); reject(new Error("Could not connect to Chromium")); };
    const onClose = (): void => { cleanup(); reject(new Error("CDP WebSocket closed before connecting")); };
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error("Timed out connecting to Chromium"));
    }, CDP_TIMEOUT_MS);
    socket.addEventListener("open", onOpen, { once: true });
    socket.addEventListener("error", onError, { once: true });
    socket.addEventListener("close", onClose, { once: true });
  });
}

async function closeSocket(socket: WebSocket): Promise<void> {
  if (socket.readyState === WebSocket.CLOSED) return;
  await new Promise<void>((resolve) => {
    const timer = setTimeout(() => {
      socket.removeEventListener("close", onClose);
      resolve();
    }, 1_000);
    const onClose = (): void => {
      clearTimeout(timer);
      resolve();
    };
    socket.addEventListener("close", onClose, { once: true });
    try {
      socket.close();
    } catch {
      clearTimeout(timer);
      socket.removeEventListener("close", onClose);
      resolve();
    }
  });
}

/**
 * Enumerate active HTTP(S) frame hostnames, or clear sessionStorage for matching
 * frames in the supplied browser context. No storage contents are read or returned.
 */
export async function scanSessionStorage(
  wsEndpoint: string,
  contextId: string,
  domain?: string,
): Promise<{ hosts: string[]; failures: number }> {
  const normalizedDomain = domain === undefined ? undefined : normalizeDomain(domain);
  const hosts = new Set<string>();
  let failures = 0;
  let socket: WebSocket | undefined;

  try {
    socket = new WebSocket(wsEndpoint);
    try {
      await connect(socket);
    } catch {
      return { hosts: [], failures: 1 };
    }
    const cdp = new CdpConnection(socket);

    let targetInfos: TargetInfo[];
    try {
      const result = await cdp.request("Target.getTargets");
      if (!Array.isArray(result?.targetInfos)) throw new Error("Invalid Target.getTargets response");
      targetInfos = result.targetInfos;
    } catch {
      return { hosts: [], failures: 1 };
    }

    const outOfProcessFrameIds = new Set(
      targetInfos.filter((target) => target.type === "iframe").map((target) => target.targetId),
    );
    const targets = targetInfos.filter((target) =>
      (target.type === "page" || target.type === "iframe") && target.browserContextId === contextId,
    );
    const processedFrameIds = new Set<string>();

    for (const target of targets) {
      let sessionId: string | undefined;
      try {
        const attached = await cdp.request("Target.attachToTarget", { targetId: target.targetId, flatten: true });
        if (typeof attached?.sessionId !== "string") throw new Error("Invalid Target.attachToTarget response");
        sessionId = attached.sessionId;
      } catch {
        failures++;
        continue;
      }

      try {
        let tree: { frameTree?: FrameTree };
        try {
          tree = await cdp.request("Page.getFrameTree", {}, sessionId);
          if (!tree?.frameTree?.frame) throw new Error("Invalid Page.getFrameTree response");
        } catch {
          failures++;
          continue;
        }

        const visit = async (node: FrameTree, isRoot = false): Promise<void> => {
          const frame = node.frame;
          if (frame?.id) {
            // An OOPIF's frame-tree placeholder is handled by its own iframe target.
            if (!isRoot && outOfProcessFrameIds.has(frame.id)) return;

            if (!processedFrameIds.has(frame.id)) {
              processedFrameIds.add(frame.id);
              if (typeof frame.url === "string" && isHttpUrl(frame.url)) {
                try {
                  const world = await cdp.request("Page.createIsolatedWorld", {
                    frameId: frame.id,
                    worldName: `pi-session-storage-scan-${++isolatedWorldSequence}`,
                    grantUniveralAccess: false,
                  }, sessionId);
                  if (typeof world?.executionContextId !== "number") {
                    throw new Error("Invalid Page.createIsolatedWorld response");
                  }

                  const domainLiteral = normalizedDomain === undefined ? "null" : JSON.stringify(normalizedDomain);
                  const expression = `(() => {
                    const protocol = location.protocol;
                    if (protocol !== "http:" && protocol !== "https:") return null;
                    const hostname = location.hostname.toLowerCase().replace(/\\.$/, "");
                    if (!hostname) return null;
                    const domain = ${domainLiteral};
                    if (domain !== null && hostname !== domain && !hostname.endsWith("." + domain)) return null;
                    if (domain !== null) {
                      try {
                        Storage.prototype.clear.call(window.sessionStorage);
                        return { hostname, cleared: true };
                      } catch {
                        return { hostname, cleared: false };
                      }
                    }
                    return { hostname };
                  })()`;
                  const evaluated = await cdp.request("Runtime.evaluate", {
                    expression,
                    contextId: world.executionContextId,
                    returnByValue: true,
                    silent: true,
                  }, sessionId);

                  if (evaluated?.exceptionDetails) {
                    failures++;
                  } else if (evaluated?.result?.value && typeof evaluated.result.value.hostname === "string") {
                    const value = evaluated.result.value;
                    hosts.add(value.hostname.toLowerCase().replace(/\.$/, ""));
                    if (normalizedDomain !== undefined && value.cleared !== true) failures++;
                  } else if (evaluated?.result?.subtype !== "null") {
                    failures++;
                  }
                } catch {
                  failures++;
                }
              }
            }
          }

          for (const child of node.childFrames ?? []) await visit(child);
        };

        try {
          await visit(tree.frameTree, true);
        } catch {
          failures++;
        }
      } finally {
        try {
          await cdp.request("Target.detachFromTarget", { sessionId });
        } catch {
          failures++;
        }
      }
    }
  } catch {
    failures++;
  } finally {
    if (socket) await closeSocket(socket);
  }

  return { hosts: [...hosts].sort(), failures };
}
