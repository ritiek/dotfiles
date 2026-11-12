import { expect, test } from "bun:test";
import { mkdirSync, readFileSync, rmSync } from "node:fs";
import plugin from "./index.ts";

// Routes by public IP: direct and `a` share one, `b` and `c` have their own.
const IP: Record<string, string> = { direct: "1.1.1.1", "a:1": "1.1.1.1", "b:1": "2.2.2.2", "c:1": "3.3.3.3" };
const status: Record<string, number> = { "b:1": 429, "c:1": 200 };
let calls: string[] = [];
globalThis.fetch = (async (url: string, init: any) => {
  const route = init?.proxy ? new URL(init.proxy).host : "direct";
  if (String(url).includes("ipify")) return new Response(IP[route]);
  calls.push(route);
  expect(await new Response(init.body).text()).toBe('{"q":1}');
  return new Response(route, { status: status[route] });
}) as any;

const home = "/tmp/opencode/ocfree-test-home";
rmSync(home, { recursive: true, force: true });
mkdirSync(`${home}/.local/share/opencode`, { recursive: true });
process.env.HOME = home;
// Last log line without its timestamp.
const logged = () => readFileSync(`${home}/.local/share/opencode/ocfree.log`, "utf8").trim().split("\n").at(-1)!.replace(/^\S+ /, "");

const creds = `${home}/creds`;
await Bun.write(creds, "u:CL:p\n");
let hook: any;
await plugin.setup({
  options: { hosts: ["a:1", "b:1", "c:1"], credentials: creds },
  session: { hook: async (_: string, cb: any) => (hook = cb) },
});
const send = async (code: number, model = "m") => {
  calls = [];
  const response = new Response("orig", { status: code });
  const event = {
    model: { id: model },
    kind: "primary",
    request: new Request("https://gw.test/v1/chat/completions", { method: "POST", body: '{"q":1}' }),
    response,
  };
  await hook(event);
  return { event, original: event.response === response };
};

test("200 passes through untouched", async () => {
  const r = await send(200);
  expect(r.original).toBe(true);
  expect(calls).toEqual([]);
  expect(logged()).toBe("m primary direct 200");
});

test("429 skips proxies on the exhausted IP and fails over", async () => {
  const r = await send(429);
  expect(calls).toEqual(["b:1", "c:1"]); // a shares direct's IP, b 429s
  expect(await r.event.response.text()).toBe("c:1");
  expect(logged()).toBe("m primary direct 429 (1.1.1.1) -> b (2.2.2.2) 429 -> c (3.3.3.3) 200");
});

test("cooled-down IPs are skipped on the next 429", async () => {
  await send(429);
  expect(calls).toEqual(["c:1"]);
  expect(logged()).toBe("m primary direct 429 (1.1.1.1) -> c (3.3.3.3) 200");
});

test("cooldowns are per model", async () => {
  await send(429, "other");
  expect(calls).toEqual(["b:1", "c:1"]);
});

test("all IPs exhausted leaves the original 429", async () => {
  status["c:1"] = 429;
  const r = await send(429);
  expect(calls).toEqual(["c:1"]);
  expect(r.original).toBe(true);
  expect(await r.event.response.text()).toBe("orig");
  expect(logged()).toBe("m primary direct 429 (1.1.1.1) -> c (3.3.3.3) 429 -> all IPs exhausted, 429 kept");
});
