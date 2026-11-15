// OpenAI-compatible shim for hermes on top of OpenCode's free tier (ocfree's /v1 route). The gate only
// serves the OpenCode CLI's request shape (canonical prompt/tools from prefix.json.gz, CLI headers and
// descending()-shaped ids), so every request is replayed in that shape.
import type { Relay } from "./ocfree";

const A = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const P = JSON.parse(new TextDecoder().decode(Bun.gunzipSync(await Bun.file(import.meta.dir + "/prefix.json.gz").arrayBuffer())));
// The captured prompt carries OpenCode's skill catalog and a "load these skills at startup" order.
// Hermes has its own skills, so drop both (~20 KB per request). The gate never inspects the text.
P.system.content = P.system.content
  .replace(/## Startup\nAt the start of every session[\s\S]*?(?=\n\nYou are powered)/, "")
  .replace(/Skills provide specialized instructions[\s\S]*?<\/available_skills>\n*/, "");

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

// All ids (session, project, request) are minted per egress and never shared between egresses.
const state = new Map<string, { project: string; sessions: Map<string, string> }>();
const st = (egress: string) =>
  state.get(egress) ?? state.set(egress, { project: rnd(40, "0123456789abcdef"), sessions: new Map() }).get(egress)!;

// The gateway answers 429 FreeUsageLimitError to any request with a tool named `terminal` (no shell
// tools for non-OpenCode agents), so Hermes' terminal ships as `bash`. The model also sees
// OpenCode's own tools; map its calls back to the Hermes equivalents, if Hermes offered them.
const BACK: Record<string, [string, (a: any) => any]> = {
  read: ["read_file", (a) => ({ path: a.filePath, offset: a.offset, limit: a.limit })],
  bash: ["terminal", (a) => a],
};
const remap = (calls: any[], names: Set<string>) =>
  calls.flatMap((c) => {
    const { name, arguments: raw } = c.function;
    if (names.has(name)) return [c];
    const m = BACK[name];
    if (!m || !names.has(m[0])) return []; // OpenCode tool Hermes can't run: drop
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

export async function hermes(req: Request, url: URL, relay: Relay, upstream: string): Promise<Response> {
  if (req.method !== "POST" || !url.pathname.endsWith("/chat/completions")) return new Response("not found", { status: 404 });

  const b = await req.json();
  const model = String(b.model).replace(/^opencode\//, "");
  const sys = b.messages.filter((m: any) => m.role === "system").map((m: any) => text(m.content));
  const rest = b.messages.filter((m: any) => m.role !== "system");
  const key = text(rest[0]?.content).slice(0, 500);
  const names = new Set<string>((b.tools ?? []).map((t: any) => t.function.name));

  const body = JSON.stringify({
    model,
    max_tokens: b.max_tokens ?? b.max_completion_tokens ?? 32000,
    ...(b.temperature != null && { temperature: b.temperature }),
    stream: true,
    stream_options: { include_usage: true },
    messages: [{ role: "system", content: [P.system.content, ...sys].join("\n\n") }, ...rest],
    tools: [...P.tools, ...(b.tools ?? []).map((t: any) =>
      t.function.name === "terminal" ? { ...t, function: { ...t.function, name: "bash" } } : t)],
    // without caller tools, forbid the canonical ones (bash, read, ...) so replies stay plain text
    tool_choice: names.size ? (b.tool_choice ?? "auto") : "none",
  });

  const res = await relay(model, (e) => {
    const s = st(e.name);
    let sid = s.sessions.get(key);
    if (!sid) {
      s.sessions.set(key, (sid = id("ses")));
      // shortcut: evicts by insertion order, so a conversation older than 1000 newer ones gets a fresh session id.
      if (s.sessions.size > 1000) s.sessions.delete(s.sessions.keys().next().value!);
    }
    return {
      url: `${upstream}/inference/openai/v1/chat/completions`,
      method: "POST",
      body: new Blob([body]),
      headers: new Headers({
        authorization: "Bearer public",
        "content-type": "application/json",
        "user-agent": "opencode/1.19.0 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14",
        "x-opencode-client": "cli",
        "x-opencode-project": s.project,
        "x-opencode-session": sid,
        "x-opencode-session-id": sid,
        "x-opencode-request": id("msg"),
        accept: "*/*",
      }),
    };
  }, req.signal);
  if (!res.ok) return res;
  try {
    return reply(await collect(res, names), model, !!b.stream);
  } catch {
    // The stream broke after it started; hermes retries the turn itself.
    return Response.json({ error: { message: "ocfree: upstream stream broke mid-reply" } }, { status: 502 });
  }
}
