// OpenAI-compatible shim for OpenCode's free tier (opencode.ai/inference).
// The gate wants the OpenCode CLI's system prompt + a `read` tool (nothing else is checked) and a descending()-shaped session id,
// so every request is wrapped in the canonical prefix (prefix.json.gz) before being forwarded.
const UP = "https://opencode.ai/inference/openai/v1/chat/completions";
const PORT = Number(process.env.PORT ?? 9997);
const GAP = 1200; // ms between upstream calls; zero-spacing bursts get 429
const A = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const P = JSON.parse(new TextDecoder().decode(Bun.gunzipSync(await Bun.file(import.meta.dir + "/prefix.json.gz").arrayBuffer())));

const rnd = (n: number, set = A) => Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => set[b % set.length]).join("");
let last = 0, counter = 0;
// Same algorithm as OpenCode's Identifier.descending(); random ids are rejected.
const id = (p: string) => {
  const t = Date.now();
  if (t !== last) { last = t; counter = 0; }
  const v = ~(BigInt(t) * 0x1000n + BigInt(++counter));
  const time = Array.from({ length: 6 }, (_, i) => Number((v >> BigInt(40 - 8 * i)) & 0xffn).toString(16).padStart(2, "0")).join("");
  return p + "_" + time + rnd(14);
};

const text = (c: any) => (typeof c === "string" ? c : (c ?? []).map((x: any) => x.text ?? "").join(""));
let next = 0;

// The free quota is per public IP. Egresses = direct + 3proxy nodes on the tailnet, deduped by public IP.
// All ids (session, project, request) are minted per IP and never shared between IPs.
type Egress = { proxy?: string; ip: string };
const CRED = process.env.CREDENTIALS_DIRECTORY ? Bun.file(process.env.CREDENTIALS_DIRECTORY + "/3proxy") : null;
const proxies = async () => {
  const [user, , pass] = ((await CRED?.text().catch(() => "")) ?? "").split("\n")[0].split(":");
  if (!user || !pass) return [];
  return (process.env.OCFREE_PROXY_HOSTS ?? "").split(",").filter(Boolean)
    .map((h) => `http://${encodeURIComponent(user)}:${encodeURIComponent(pass)}@${h}`);
};
let egresses: Egress[] = [{ ip: "direct" }];
const refresh = async () => {
  const found = await Promise.all([undefined, ...(await proxies())].map(async (proxy) => {
    try {
      const ip = (await (await fetch("https://api.ipify.org", { proxy, signal: AbortSignal.timeout(10000) })).text()).trim();
      return /^[\d.:a-f]+$/i.test(ip) ? { proxy, ip } : null;
    } catch { return null; }
  }));
  const uniq = new Map<string, Egress>();
  for (const e of found) if (e && !uniq.has(e.ip)) uniq.set(e.ip, e);
  if (uniq.size) egresses = [...uniq.values()];
  console.log("egresses:", egresses.map((e) => e.ip).join(", "));
};
await refresh();
setInterval(refresh, 600_000);
const state = new Map<string, { until: number; project: string; sessions: Map<string, string> }>();
const st = (ip: string) => {
  let s = state.get(ip);
  if (!s) state.set(ip, (s = { until: 0, project: rnd(40, "0123456789abcdef"), sessions: new Map() }));
  return s;
};

// The model sees OpenCode's tools; rewrite its calls into the caller's (Hermes) equivalents.
// Each entry: hermes tool name + arg translator. Only applied if the caller actually offered that tool.
const pick = (a: any, m: Record<string, string>) =>
  Object.fromEntries(Object.entries(m).filter(([k]) => a[k] !== undefined).map(([k, v]) => [v, a[k]]));
const MAP: Record<string, [string, (a: any) => any]> = {
  read: ["read_file", (a) => pick(a, { filePath: "path", offset: "offset", limit: "limit" })],
};
const remap = (calls: any[], names: Set<string>) =>
  calls.flatMap((c) => {
    const { name, arguments: raw } = c.function;
    if (names.has(name)) return [c];
    const m = MAP[name];
    if (!m || !names.has(m[0])) return []; // unknown OpenCode tool Hermes can't run: drop
    try {
      return [{ ...c, function: { name: m[0], arguments: JSON.stringify(m[1](JSON.parse(raw || "{}"))) } }];
    } catch {
      return [];
    }
  });

// Collapse the upstream SSE stream into one result, with tool calls remapped.
const collect = async (res: Response, names: Set<string>) => {
  let content = "", usage: any, finish = "stop";
  let calls: any[] = [];
  for (const line of (await res.text()).split("\n")) {
    if (!line.startsWith("data: ") || line.includes("[DONE]")) continue;
    const j = JSON.parse(line.slice(6));
    usage = j.usage ?? usage;
    const c = j.choices?.[0];
    if (!c) continue;
    finish = c.finish_reason ?? finish;
    content += c.delta?.content ?? "";
    for (const t of c.delta?.tool_calls ?? []) {
      const k = (calls[t.index ?? 0] ??= { id: t.id, type: "function", function: { name: "", arguments: "" } });
      k.id ??= t.id;
      k.function.name += t.function?.name ?? "";
      k.function.arguments += t.function?.arguments ?? "";
    }
  }
  calls = remap(calls.filter(Boolean), names);
  if (!calls.length && finish === "tool_calls") finish = "stop";
  return { content, usage, finish, calls };
};

const reply = (r: Awaited<ReturnType<typeof collect>>, model: string, stream: boolean) => {
  const base = { id: id("chatcmpl"), created: Math.floor(Date.now() / 1000), model };
  if (!stream) {
    const message: any = { role: "assistant", content: r.content || null };
    if (r.calls.length) message.tool_calls = r.calls;
    return Response.json({ ...base, object: "chat.completion", choices: [{ index: 0, message, finish_reason: r.finish }], usage: r.usage });
  }
  // Synthetic SSE: the full reply is already known, so send it as a few chunks.
  const chunk = (delta: any, finish_reason: string | null = null, usage?: any) =>
    `data: ${JSON.stringify({ ...base, object: "chat.completion.chunk", choices: usage ? [] : [{ index: 0, delta, finish_reason }], ...(usage && { usage }) })}\n\n`;
  const out = [chunk({ role: "assistant", content: r.content })];
  r.calls.forEach((c, index) => out.push(chunk({ tool_calls: [{ index, ...c }] })));
  out.push(chunk({}, r.finish));
  if (r.usage) out.push(chunk({}, null, r.usage));
  out.push("data: [DONE]\n\n");
  return new Response(out.join(""), { headers: { "content-type": "text/event-stream" } });
};

Bun.serve({
  hostname: "127.0.0.1",
  port: PORT,
  idleTimeout: 255,
  async fetch(req) {
    const url = new URL(req.url);
    if (req.method === "GET" && url.pathname.endsWith("/models"))
      return Response.json({ object: "list", data: ["deepseek-v4.1-flash-free"].map((id) => ({ id, object: "model" })) });
    if (req.method !== "POST" || !url.pathname.endsWith("/chat/completions")) return new Response("not found", { status: 404 });

    const b = await req.json();
    const model = String(b.model).replace(/^opencode\//, "");
    const sys = b.messages.filter((m: any) => m.role === "system").map((m: any) => text(m.content));
    const rest = b.messages.filter((m: any) => m.role !== "system");
    const key = text(rest[0]?.content).slice(0, 500);

    const tools = b.tools?.length ? [...P.tools, ...b.tools] : P.tools;
    const body = JSON.stringify({
      model,
      max_tokens: b.max_tokens ?? b.max_completion_tokens ?? 32000,
      ...(b.temperature != null && { temperature: b.temperature }),
      stream: true,
      stream_options: { include_usage: true },
      messages: [{ role: "system", content: [P.system.content, ...sys].join("\n\n") }, ...rest],
      tools,
      // without caller tools, forbid the canonical ones (bash, read, ...) so replies stay plain text
      tool_choice: b.tools?.length ? (b.tool_choice ?? "auto") : "none",
    });

    const wait = Math.max(0, next - Date.now());
    next = Math.max(Date.now(), next) + GAP;
    if (wait) await Bun.sleep(wait);

    // First egress whose IP isn't out of quota; on 429 mark it exhausted and fail over with fresh ids.
    let res: Response | undefined;
    for (const e of egresses) {
      const s = st(e.ip);
      if (s.until > Date.now()) continue;
      let sid = s.sessions.get(key);
      if (!sid) s.sessions.set(key, (sid = id("ses")));
      res = await fetch(UP, {
        method: "POST",
        body,
        proxy: e.proxy,
        headers: {
          authorization: "Bearer public",
          "content-type": "application/json",
          "user-agent": "opencode/1.19.0 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14",
          "x-opencode-client": "cli",
          "x-opencode-project": s.project,
          "x-opencode-session": sid,
          "x-opencode-session-id": sid,
          "x-opencode-request": id("msg"),
          accept: "*/*",
        },
      }).catch(() => undefined);
      if (!res) continue; // egress unreachable
      if (res.status !== 429) break;
      s.until = Date.now() + (Number(res.headers.get("retry-after")) || 3600) * 1000;
      console.log(`quota exhausted on ${e.ip} until ${new Date(s.until).toISOString()}`);
      await res.body?.cancel();
      res = undefined;
    }
    if (!res) {
      const soon = Math.min(...egresses.map((e) => st(e.ip).until));
      return new Response("all egresses exhausted or unreachable", { status: 429, headers: { "retry-after": String(Math.max(60, Math.ceil((soon - Date.now()) / 1000))) } });
    }
    if (!res.ok) return new Response(res.body, { status: res.status, headers: { "content-type": res.headers.get("content-type") ?? "text/plain" } });
    return reply(await collect(res, new Set((b.tools ?? []).map((t: any) => t.function.name))), model, !!b.stream);
  },
});
console.log(`ocfree listening on 127.0.0.1:${PORT}`);
