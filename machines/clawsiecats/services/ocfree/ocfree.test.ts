// bun test: the relay's failover rules against fake egresses. Bun sends plain-http requests to a proxy
// in absolute form, so each fake "proxy" can answer as the gateway with a scripted behaviour.
import { afterAll, beforeEach, expect, test } from "bun:test";
import { serve, type Egress } from "./ocfree";

type Mode = "ok" | "quota" | "broken" | "hang" | "die" | "blocked" | "bad" | "flaky";
const mode: Record<string, Mode> = {};
const hits: Record<string, number> = {};
const seen: Record<string, string | null> = {}; // authorization header each fake received
const cf = { "cf-ray": "test" };

function fake(name: string, hostname = "127.0.0.1") {
  return Bun.serve({
    hostname, port: 0, idleTimeout: 0,
    fetch(req) {
      hits[name] = (hits[name] ?? 0) + 1;
      seen[name] = req.headers.get("authorization");
      switch (mode[name]) {
        case "ok": return new Response(`data: ${name}\n\n`, { headers: { ...cf, "content-type": "text/event-stream" } });
        case "quota": return Response.json({ error: { message: "Free usage limit reached" } }, { status: 429, headers: { ...cf, "retry-after": "9999" } });
        case "broken": return new Response("proxy error", { status: 502 }); // no cf-ray: the proxy itself failed
        case "hang": return new Promise<Response>(() => {});
        case "die": return new Response(new ReadableStream({ start(c) { c.error(new Error("boom")); } }), { headers: cf });
        case "blocked": return new Response("<html>challenge</html>", { status: 403, headers: { ...cf, "content-type": "text/html", "cf-mitigated": "challenge" } });
        case "bad": return Response.json({ error: "bad request" }, { status: 400, headers: cf });
        case "flaky": return hits[name] === 1 ? new Response("oops", { status: 503, headers: cf }) : new Response(`data: ${name}\n\n`, { headers: cf });
      }
      return new Response("unset", { status: 500 });
    },
  });
}

const fakes = Object.fromEntries(["a", "b", "c"].map((n) => [n, fake(n)]));
const direct = fake("direct"); // listens on IPv4 only, so a direct IPv6 egress cannot reach it
const closed = Bun.serve({ port: 0, fetch: () => new Response() });
const closedPort = closed.port;
closed.stop(true);
const via = (n: string): Egress => ({ name: n, proxy: `http://127.0.0.1:${fakes[n].port}`, family: 4 });
const servers: { stop(force?: boolean): unknown }[] = [];

// The proxied upstream is a documentation address the fake proxies answer for: Bun skips even an
// explicit proxy for NO_PROXY hosts (read once at startup), which often include 127.0.0.1.
function mw(egresses: Egress[], upstream = "http://192.0.2.1:9", headerTimeout = 300) {
  const s = serve({ key: "k", egresses, upstream, port: 0, hostname: "127.0.0.1", headerTimeout, connectTimeout: 200, quotaCooldown: 200, deadBackoff: [5_000, 10_000], log: () => {} });
  servers.push(s);
  return (headers: Record<string, string> = { "x-ocfree-key": "k", authorization: "Bearer public" }) =>
    fetch(`${s.url}opencode/chat/completions`, { method: "POST", headers, body: JSON.stringify({ model: "m" }) });
}

beforeEach(() => {
  for (const k of Object.keys(hits)) delete hits[k];
  for (const k of Object.keys(mode)) delete mode[k];
});
afterAll(() => {
  for (const s of [...servers, ...Object.values(fakes), direct]) s.stop(true);
});

test("429 moves to the next egress, which stays in use after the first recovers", async () => {
  Object.assign(mode, { a: "quota", b: "ok", c: "ok" });
  const post = mw([via("a"), via("b"), via("c")]);
  const r1 = await post();
  expect(await r1.text()).toBe("data: b\n\n");
  expect(r1.headers.get("x-ocfree-egress")).toBe("b");
  await Bun.sleep(250); // a's quota cooldown is over, but b still works
  expect(await (await post()).text()).toBe("data: b\n\n");
  expect(hits).toEqual({ a: 1, b: 2 });
});

test("unreachable, broken and hanging proxies fail over", async () => {
  Object.assign(mode, { a: "broken", b: "hang", c: "ok" });
  const post = mw([{ name: "gone", proxy: `http://127.0.0.1:${closedPort}`, family: 4 }, via("a"), via("b"), via("c")]);
  expect(await (await post()).text()).toBe("data: c\n\n");
});

test("an offline proxy host is skipped after a short connect check, for both families", async () => {
  mode.a = "ok";
  const blackhole = "http://10.255.255.1:9"; // unrouted: packets vanish, like a tailnet peer that is off
  const post = mw([{ name: "off/v6", proxy: blackhole, family: 6 }, { name: "off/v4", proxy: blackhole, family: 4 }, via("a")],
    undefined, 10_000);
  const t = Date.now();
  expect(await (await post()).text()).toBe("data: a\n\n");
  expect(Date.now() - t).toBeLessThan(1_000); // one 200ms connect check, not two 10s header timeouts
});

test("a stream that dies before its first chunk fails over", async () => {
  Object.assign(mode, { a: "die", b: "ok" });
  expect(await (await mw([via("a"), via("b")])()).text()).toBe("data: b\n\n");
});

test("a Cloudflare block fails over", async () => {
  Object.assign(mode, { a: "blocked", b: "ok" });
  expect(await (await mw([via("a"), via("b")])()).text()).toBe("data: b\n\n");
});

test("request errors pass through without trying another egress", async () => {
  Object.assign(mode, { a: "bad", b: "ok" });
  const r = await mw([via("a"), via("b")])();
  expect(r.status).toBe(400);
  expect(hits.b).toBeUndefined();
});

test("a gateway 5xx is retried once on the same egress", async () => {
  Object.assign(mode, { a: "flaky", b: "ok" });
  expect(await (await mw([via("a"), via("b")])()).text()).toBe("data: a\n\n");
  expect(hits).toEqual({ a: 2 });
});

test("every egress out of quota answers 429 with retry-after", async () => {
  Object.assign(mode, { a: "quota", b: "quota" });
  const post = mw([via("a"), via("b")]);
  const r = await post();
  expect(r.status).toBe(429);
  expect(Number(r.headers.get("retry-after"))).toBeGreaterThan(0);
  expect(await r.text()).toContain("Free usage limit reached");
  expect((await post()).status).toBe(429); // both cooling down: answered without another upstream request
  expect(hits).toEqual({ a: 1, b: 1 });
});

test("a route without IPv6 falls back to IPv4 on the same route", async () => {
  mode.direct = "ok";
  const post = mw([{ name: "direct/v6", family: 6 }, { name: "direct/v4", family: 4 }], `http://localhost:${direct.port}`);
  const r = await post();
  expect(r.headers.get("x-ocfree-egress")).toBe("direct/v4");
});

test("a wrong key is refused, and the key never reaches the gateway", async () => {
  mode.a = "ok";
  const post = mw([via("a")]);
  expect((await post({ "x-ocfree-key": "nope" })).status).toBe(401);
  expect(hits.a).toBeUndefined();
  expect((await post({ authorization: "Bearer k" })).status).toBe(200);
  expect(seen.a).toBe("Bearer public");
});
