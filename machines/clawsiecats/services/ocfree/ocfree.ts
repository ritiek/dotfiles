// Middleman for OpenCode's free tier (opencode.ai/inference), shared by OpenCode on every machine and
// by hermes. The gateway counts free usage per client IP, so requests leave through one egress at a
// time: this host directly, or a 3proxy node on the tailnet, each over IPv6 and then IPv4. An egress is
// kept until it runs out of quota or stops working; only then does the next one take over, and an
// earlier one is used again only after a later one fails. Nothing is probed in the background: real
// requests are the only check, so an egress's state is whatever its last request showed.
//   /.well-known/opencode  public: lets `opencode auth login <origin>` register the clawsiecats provider.
//   /opencode/config       that provider, with the free models read live from upstream's /models.
//   /opencode/*            OpenCode's model requests, passed through unchanged.
//   /v1/models             the same free models, for OpenAI-style clients (hermes discovers them here).
//   /v1/*                  hermes' OpenAI-compatible shim (./hermes.ts).
//   /status                which egress each model uses, and which ones are cooling down or failing.
// Everything except the well-known manifest needs the key.
import { createHash, timingSafeEqual } from "node:crypto";
import { hermes } from "./hermes";

export type Egress = { name: string; proxy?: string; family: 4 | 6 };
export type Upstream = { url: string; method: string; headers: Headers; body?: Blob };
export type Relay = (model: string, build: (e: Egress) => Upstream, signal: AbortSignal) => Promise<Response>;

type Options = {
  key: string;
  egresses: Egress[];
  upstream?: string;
  port?: number;
  hostname?: string;
  // The gateway answers with headers before the model starts generating, so a long wait means a stuck route.
  headerTimeout?: number;
  // retry-after is the daily reset, but an IP often has quota again much sooner.
  quotaCooldown?: number;
  // A failing egress is skipped for min, doubling per failure up to max. A Cloudflare block gets max.
  deadBackoff?: [number, number];
  // An offline proxy host drops packets, so fetch would hang until headerTimeout; a TCP connect to
  // the proxy shows it much sooner. Only done when switching to an egress, never for the one in use.
  connectTimeout?: number;
  log?: (line: string) => void;
};

type Outcome = { kind: "served" | "quota" | "down" | "blocked"; res?: Response; retryMs?: number; note: string };

// Headers that describe one hop, or that only ocfree reads, are never forwarded.
const HOP = ["host", "connection", "keep-alive", "proxy-authorization", "proxy-connection", "te", "trailer",
  "transfer-encoding", "upgrade", "content-length", "accept-encoding", "x-ocfree-key"];
// fetch() already decompressed the body, so the length and encoding no longer describe it.
const STALE = ["content-encoding", "content-length", "transfer-encoding", "connection"];

const digest = (s: string) => createHash("sha256").update(s).digest();

// OpenCode runs this on `opencode auth login <origin>` and stores what it prints as the key.
const LOGIN = 'if [ -z "$CLAWSIECATS_API_KEY" ]; then echo "Set CLAWSIECATS_API_KEY to your clawsiecats API key, then log in again." >&2; exit 1; fi; printf %s "$CLAWSIECATS_API_KEY"';

// OpenCode's well-known manifest. After login, every OpenCode start fetches remote_config with the
// stored key (substituted for {env:CLAWSIECATS_API_KEY}), so the model list is always current.
const manifest = (origin: string) => ({
  auth: { command: ["sh", "-c", LOGIN], env: "CLAWSIECATS_API_KEY" },
  remote_config: { url: `${origin}/opencode/config`, headers: { authorization: "Bearer {env:CLAWSIECATS_API_KEY}" } },
});

// "image/png" -> "image": OpenCode's capability names are coarser than upstream's MIME types.
const media = (m: string) => (m === "application/pdf" ? "pdf" : m.split("/")[0]);

// The clawsiecats provider for OpenCode, from upstream /models entries (models.dev v2 shape).
const providerConfig = (models: any[], origin: string) => ({
  providers: {
    clawsiecats: {
      name: "clawsiecats",
      package: "@opencode/ai/providers/openai-compatible",
      settings: { baseURL: `${origin}/opencode`, apiKey: "{env:CLAWSIECATS_API_KEY}" },
      models: Object.fromEntries(models.map((m) => {
        const [api] = Object.values<any>(m.api ?? {});
        return [m.id, {
          name: m.name,
          family: m.family,
          // Anthropic-format models get their own package; ocfree routes their /messages upstream.
          package: api?.sdk?.opencodeai,
          capabilities: {
            tools: !!m.capabilities?.tools?.supported,
            reasoning: m.capabilities?.reasoning,
            input: [...new Set((m.modalities?.input ?? ["text"]).map(media))],
            output: ["text"],
          },
          limit: m.limit,
          ...(api?.compatibility?.reasoning_field && { compatibility: { reasoningField: api.compatibility.reasoning_field } }),
        }];
      })),
    },
  },
});

export function relayer(egresses: Egress[], o: Required<Pick<Options, "headerTimeout" | "quotaCooldown" | "deadBackoff" | "connectTimeout" | "log">>) {
  const active = new Map<string, number>(); // model -> index of the egress in use
  const quota = new Map<string, number>(); // `${egress}|${model}` -> end of its cooldown
  const dead = new Map<string, { until: number; wait: number }>(); // egress -> backoff
  let lastQuota: { body: string; type: string } | undefined; // replayed when every egress is out
  const [deadMin, deadMax] = o.deadBackoff;
  const qkey = (e: Egress, model: string) => `${e.name}|${model}`;
  const markDown = (e: Egress, blocked = false) => {
    const prev = dead.get(e.name);
    const wait = blocked ? deadMax : prev ? Math.min(prev.wait * 2, deadMax) : deadMin;
    dead.set(e.name, { until: Date.now() + wait, wait });
  };

  function reachable(proxy: string) {
    const { hostname, port } = new URL(proxy);
    return new Promise<boolean>((resolve) => {
      let done = false;
      const finish = (ok: boolean) => !done && ((done = true), clearTimeout(timer), resolve(ok));
      const timer = setTimeout(() => finish(false), o.connectTimeout);
      Bun.connect({
        hostname, port: Number(port),
        socket: { open: (s) => (s.end(), finish(true)), data() {}, error: () => finish(false), connectError: () => finish(false) },
      }).then((s) => done && s.end(), () => finish(false));
    });
  }

  // Pin the address family by resolving the host here and connecting to the address itself; that
  // also holds through a proxy, which then never resolves anything. TLS still checks the hostname.
  async function via(e: Egress, up: Upstream, signal: AbortSignal) {
    const url = new URL(up.url);
    const { host, hostname } = url;
    const [{ address }] = await Bun.dns.lookup(hostname, { family: e.family });
    url.hostname = e.family === 6 ? `[${address}]` : address;
    const headers = new Headers(up.headers);
    headers.set("host", host);
    return fetch(url, {
      method: up.method, headers, body: up.body, proxy: e.proxy, signal, redirect: "manual",
      tls: { serverName: hostname },
    });
  }

  async function attempt(e: Egress, up: Upstream, signal: AbortSignal): Promise<Outcome> {
    for (let tries = 0; ; tries++) {
      // Stays linked to the client for the whole body, so a client that leaves stops the upstream request.
      const ctrl = new AbortController();
      signal.addEventListener("abort", () => ctrl.abort(signal.reason), { once: true });
      const timer = setTimeout(() => ctrl.abort(new Error("no response headers")), o.headerTimeout);
      let res: Response;
      try {
        res = await via(e, up, ctrl.signal);
      } catch (err: any) {
        if (signal.aborted) throw err;
        return { kind: "down", note: ctrl.signal.aborted ? "timeout" : (err?.code ?? err?.name ?? "error") };
      } finally {
        clearTimeout(timer);
      }
      // opencode.ai sits behind Cloudflare, so every gateway answer carries cf-ray; one without it came
      // from the proxy (CONNECT refused, auth failed, its own uplink down).
      if (!res.headers.has("cf-ray")) {
        await res.body?.cancel();
        return { kind: "down", note: `proxy-${res.status}` };
      }
      if (res.status === 429) {
        lastQuota = { body: await res.text(), type: res.headers.get("content-type") ?? "application/json" };
        return { kind: "quota", retryMs: Number(res.headers.get("retry-after")) * 1000 || Infinity, note: "429" };
      }
      if (res.headers.has("cf-mitigated") || (res.status === 403 && /html/.test(res.headers.get("content-type") ?? ""))) {
        await res.body?.cancel();
        return { kind: "blocked", note: `blocked-${res.status}` };
      }
      // A gateway 5xx says nothing about the egress: retry it once here, then let the client retry.
      if (res.status >= 500 && tries === 0) {
        await res.body?.cancel();
        await Bun.sleep(1000);
        continue;
      }
      const headers = new Headers(res.headers);
      for (const h of STALE) headers.delete(h);
      headers.set("x-ocfree-egress", e.name);
      if (!res.ok || !res.body) return { kind: "served", res: new Response(res.body, { status: res.status, headers }), note: String(res.status) };
      // Commit point: nothing reaches the client before the first body chunk, so a stream that dies
      // before it can still move to the next egress.
      const reader = res.body.getReader();
      let first: ReadableStreamReadResult<Uint8Array>;
      try {
        first = await reader.read();
      } catch (err) {
        if (signal.aborted) throw err;
        return { kind: "down", note: "stream-died" };
      }
      const body = new ReadableStream<Uint8Array>({
        start(c) {
          if (first.done) c.close();
          else c.enqueue(first.value);
        },
        async pull(c) {
          const { done, value } = await reader.read();
          if (done) c.close();
          else c.enqueue(value);
        },
        cancel(why) {
          return reader.cancel(why);
        },
      });
      return { kind: "served", res: new Response(body, { status: res.status, headers }), note: String(res.status) };
    }
  }

  const relay: Relay = async (model, build, signal) => {
    const now = Date.now();
    const start = active.get(model) ?? 0;
    const ring = egresses.map((_, i) => (start + i) % egresses.length)
      .filter((i) => (quota.get(qkey(egresses[i], model)) ?? 0) <= now);
    // Recently failed egresses go last rather than being skipped: their state may be stale by now.
    const failing = (i: number) => (dead.get(egresses[i].name)?.until ?? 0) > now;
    const order = [...ring.filter((i) => !failing(i)), ...ring.filter(failing)];
    const trail: string[] = [];
    const offline = new Set<string>(); // proxies found down during this request
    for (const i of order) {
      const e = egresses[i];
      if (e.proxy && offline.has(e.proxy)) continue;
      if (e.proxy && i !== active.get(model) && !(await reachable(e.proxy))) {
        // The proxy itself is down, whatever the family: skip every egress that goes through it.
        offline.add(e.proxy);
        for (const x of egresses) if (x.proxy === e.proxy) markDown(x);
        trail.push(`${e.name}:proxy-unreachable`);
        continue;
      }
      const r = await attempt(e, build(e), signal);
      trail.push(`${e.name}:${r.note}`);
      if (r.kind === "quota") {
        quota.set(qkey(e, model), Date.now() + Math.min(r.retryMs!, o.quotaCooldown));
        continue;
      }
      if (r.kind === "down" || r.kind === "blocked") {
        markDown(e, r.kind === "blocked");
        continue;
      }
      dead.delete(e.name);
      active.set(model, i);
      o.log(`${model || "-"} ${trail.join(" ")}`);
      return r.res!;
    }
    o.log(`${model || "-"} ${trail.join(" ") || "(every egress cooling down)"} -> none left`);
    const cooling = egresses.map((e) => quota.get(qkey(e, model)) ?? 0).filter((t) => t > Date.now());
    if (cooling.length) {
      const retry = Math.max(1, Math.ceil((Math.min(...cooling) - Date.now()) / 1000));
      return new Response(lastQuota?.body ?? JSON.stringify({ error: { message: "Free usage limit reached on every egress" } }), {
        status: 429,
        headers: { "content-type": lastQuota?.type ?? "application/json", "retry-after": String(retry) },
      });
    }
    return Response.json({ error: { message: `ocfree: no egress reached the gateway (${trail.join(", ")})` } }, { status: 502 });
  };

  const iso = (t?: number) => (t && t > Date.now() ? new Date(t).toISOString() : undefined);
  const status = () => ({
    active: Object.fromEntries([...active].map(([m, i]) => [m || "-", egresses[i].name])),
    egresses: egresses.map((e) => ({
      name: e.name,
      failingUntil: iso(dead.get(e.name)?.until),
      quotaUntil: Object.fromEntries([...quota].filter(([k, t]) => k.startsWith(`${e.name}|`) && t > Date.now())
        .map(([k, t]) => [k.slice(e.name.length + 1) || "-", iso(t)])),
    })),
  });

  return { relay, status };
}

export function serve(o: Options) {
  const upstream = o.upstream ?? "https://opencode.ai";
  const { relay, status } = relayer(o.egresses, {
    headerTimeout: o.headerTimeout ?? 60_000,
    quotaCooldown: o.quotaCooldown ?? 300_000,
    deadBackoff: o.deadBackoff ?? [60_000, 3_600_000],
    connectTimeout: o.connectTimeout ?? 3_000,
    log: o.log ?? console.log,
  });
  const want = digest(o.key);
  return Bun.serve({
    hostname: o.hostname ?? "0.0.0.0",
    port: o.port ?? 9997,
    idleTimeout: 0, // replies can stay silent for minutes while the model thinks
    async fetch(req) {
      const url = new URL(req.url);
      const origin = `${req.headers.get("x-forwarded-proto") ?? url.protocol.slice(0, -1)}://${url.host}`;
      if (url.pathname === "/.well-known/opencode") return Response.json(manifest(origin));
      const bearer = req.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
      if (!timingSafeEqual(digest(req.headers.get("x-ocfree-key") ?? bearer ?? ""), want))
        return Response.json({ error: { message: "ocfree: invalid key" } }, { status: 401 });
      if (url.pathname === "/status") return Response.json(status());
      if (url.pathname === "/opencode/config" || url.pathname === "/opencode/models" || url.pathname === "/v1/models") {
        // Live on every call, trimmed to the free models: ocfree only ever sends the free tier's key.
        const res = await relay("", () => ({
          url: `${upstream}/inference/openai/v1/models`, method: "GET", headers: new Headers({ accept: "application/json" }),
        }), req.signal);
        if (!res.ok) return res;
        const free = (((await res.json()) as { data?: any[] }).data ?? []).filter((m) => m.cost?.text?.input?.price === 0);
        if (url.pathname === "/opencode/config") return Response.json(providerConfig(free, origin));
        if (url.pathname === "/opencode/models") return Response.json({ object: "list", data: free });
        // Plain OpenAI model entries for OpenAI-style clients: hermes' parser crashes on the nested
        // catalog fields, and it reads the window from context_length (models.dev's `limit` it ignores,
        // then guesses and overruns the free tier's real one, deepseek's 200K for one).
        return Response.json({
          object: "list",
          data: free.map((m) => ({
            id: m.id, object: "model", created: m.created, owned_by: m.owned_by, name: m.name,
            context_length: m.limit?.context, max_completion_tokens: m.limit?.output,
          })),
        });
      }
      if (url.pathname.startsWith("/v1/")) return hermes(req, url, relay, upstream);
      if (!url.pathname.startsWith("/opencode/")) return new Response("not found", { status: 404 });

      const rest = url.pathname.slice("/opencode".length);
      // Most free models speak OpenAI's API; the Anthropic-format ones post to /messages.
      const target = `${upstream}/inference/${rest.startsWith("/messages") ? "anthropic" : "openai"}/v1${rest}${url.search}`;
      const buf = req.method === "GET" || req.method === "HEAD" ? undefined : await req.arrayBuffer();
      let model = "";
      try {
        model = String(JSON.parse(new TextDecoder().decode(buf)).model ?? "");
      } catch {}
      const headers = new Headers(req.headers);
      for (const h of HOP) headers.delete(h);
      // Without x-ocfree-key the bearer token was the key: never forward it upstream.
      if (!req.headers.has("x-ocfree-key")) headers.set("authorization", "Bearer public");
      const body = buf && new Blob([buf]);
      return relay(model, () => ({ url: target, method: req.method, headers, body }), req.signal);
    },
  });
}

if (import.meta.main) {
  const dir = process.env.CREDENTIALS_DIRECTORY ?? "";
  const key = (await Bun.file(`${dir}/key`).text()).trim();
  if (!key) throw new Error("ocfree: the key credential is empty");
  const proxies = (process.env.OCFREE_PROXIES ?? "").split(",").filter(Boolean);
  const [user, , pass] = (await Bun.file(`${dir}/3proxy`).text().catch(() => "")).split("\n")[0].split(":");
  if (proxies.length && !(user && pass)) throw new Error("ocfree: OCFREE_PROXIES needs the 3proxy credential (user:CL:pass)");
  // Every route over IPv6, then IPv4. Whether a route has working IPv6 is never assumed: one without
  // it fails at its first request and is skipped from then on.
  const egresses: Egress[] = [undefined, ...proxies].flatMap((h) =>
    ([6, 4] as const).map((family) => ({
      name: `${h ? h.split(".")[0] : "direct"}/v${family}`,
      proxy: h && `http://${encodeURIComponent(user)}:${encodeURIComponent(pass)}@${h}`,
      family,
    })));
  const server = serve({ key, egresses, port: Number(process.env.PORT ?? 9997) });
  console.log(`ocfree listening on :${server.port}, egresses: ${egresses.map((e) => e.name).join(", ")}`);
}
