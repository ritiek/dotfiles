// IP failover for OpenCode's free models. The gateway counts free usage per client IP, so when it
// answers 429, re-send the same request through a 3proxy node on another public IP and hand
// OpenCode that reply instead. Proxies are grouped by public IP, looked up on the first 429.
// Every free-model request gets one line in ~/.local/share/opencode/ocfree.log.
import { appendFileSync } from "node:fs";

const COOLDOWN = 300_000; // retry-after is the daily reset, but an IP often has quota again sooner
const IP_TTL = 600_000;

export default {
  id: "ocfree",
  async setup(ctx: any) {
    const { hosts = [], credentials = "" } = ctx.options as { hosts?: string[]; credentials?: string };
    const [user, , pass] = (await Bun.file(credentials).text().catch(() => "")).split("\n")[0].split(":");
    if (!user || !pass) return;
    // undefined = OpenCode's own route: direct, or the service's HTTPS_PROXY (opencode-via).
    const routes = [undefined, ...hosts.map((h) => `http://${encodeURIComponent(user)}:${encodeURIComponent(pass)}@${h}`)];

    let ips = new Map<string | undefined, string>(), checked = 0;
    const lookup = async () => {
      if (Date.now() - checked < IP_TTL) return ips;
      const found = await Promise.all(routes.map(async (proxy) => {
        try {
          // Short timeout: an offline proxy would otherwise stall the first failover.
          const ip = (await (await fetch("https://api.ipify.org", { proxy, signal: AbortSignal.timeout(3_000) })).text()).trim();
          return /^[\d.:a-f]+$/i.test(ip) ? ([proxy, ip] as const) : null;
        } catch { return null; }
      }));
      ips = new Map(found.filter((e) => e !== null));
      if (ips.size) checked = Date.now(); // all lookups failed: retry on the next 429
      return ips;
    };

    // shortcut: never rotated (~100 bytes per free-model request), add rotation if it grows large.
    const log = (event: any, msg: string) => {
      try {
        appendFileSync(`${process.env.HOME}/.local/share/opencode/ocfree.log`,
          `${new Date().toISOString()} ${event.model.id} ${event.kind} ${msg}\n`);
      } catch {} // a failed log line must not fail the request
    };
    // Host name only, so the credentials in the proxy URL never reach the log.
    const name = (proxy: string) => new URL(proxy).hostname.split(".")[0];

    const until = new Map<string, number>(); // `${ip}|${model}` -> end of its cooldown
    await ctx.session.hook("http.response", async (event: any) => {
      if (event.response.status !== 429) return log(event, `direct ${event.response.status}`);
      const ip = await lookup();
      const key = (proxy?: string) => `${ip.get(proxy)}|${event.model.id}`;
      until.set(key(undefined), Date.now() + COOLDOWN);
      // OpenCode sends its own copy of the body, so this one is still unread.
      const { url, method, headers } = event.request;
      const body = await event.request.arrayBuffer();
      const trail = [`direct 429 (${ip.get(undefined) ?? "?"})`];
      for (const proxy of routes.slice(1)) {
        if (!ip.has(proxy) || (until.get(key(proxy)) ?? 0) > Date.now()) continue;
        const res = await fetch(url, { method, headers, body, proxy }).catch(() => undefined);
        trail.push(`-> ${name(proxy!)} (${ip.get(proxy)}) ${res?.status ?? "failed"}`);
        if (!res) continue;
        if (res.status === 429) {
          until.set(key(proxy), Date.now() + COOLDOWN);
          await res.body?.cancel();
          continue;
        }
        log(event, trail.join(" "));
        await event.response.body?.cancel();
        event.response = res;
        return;
      }
      // Every IP is out of quota: the untouched 429 lets OpenCode report the free limit.
      log(event, [...trail, "-> all IPs exhausted, 429 kept"].join(" "));
    }, { providerID: "opencode" });
  },
};
