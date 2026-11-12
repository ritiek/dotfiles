// IP failover for OpenCode's free models. The gateway counts free usage per client IP, so when it
// answers 429, re-send the same request through a 3proxy node on another public IP and hand
// OpenCode that reply instead. Proxies are grouped by public IP, looked up on the first 429.
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

    const until = new Map<string, number>(); // `${ip}|${model}` -> end of its cooldown
    await ctx.session.hook("http.response", async (event: any) => {
      if (event.response.status !== 429) return;
      const ip = await lookup();
      const key = (proxy?: string) => `${ip.get(proxy)}|${event.model.id}`;
      until.set(key(undefined), Date.now() + COOLDOWN);
      // OpenCode sends its own copy of the body, so this one is still unread.
      const { url, method, headers } = event.request;
      const body = await event.request.arrayBuffer();
      for (const proxy of routes.slice(1)) {
        if (!ip.has(proxy) || (until.get(key(proxy)) ?? 0) > Date.now()) continue;
        const res = await fetch(url, { method, headers, body, proxy }).catch(() => undefined);
        if (!res) continue;
        if (res.status === 429) {
          until.set(key(proxy), Date.now() + COOLDOWN);
          await res.body?.cancel();
          continue;
        }
        await event.response.body?.cancel();
        event.response = res;
        return;
      }
      // Every IP is out of quota: the untouched 429 lets OpenCode report the free limit.
    }, { providerID: "opencode" });
  },
};
