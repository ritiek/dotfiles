# switchboard — router cutover handoff

Self-contained context for turning `switchboard` into the household router.
Written so it can be read offline, with no assistant and no network.

**This repo is public. No credentials in this file.** Secrets live in
`machines/switchboard/secrets.yaml` (sops). Where a password is needed the key
name is given, not the value.

---

## 1. What we are doing

`switchboard` (Radxa Cubie A5E) used to be a DNS/monitoring appliance running
Pi-hole, Gatus and homepage-dashboard. It is being turned into the household's
primary router, replacing the ISP ONT's routing role.

Two variants exist. The import in `machines/switchboard/default.nix` selects one.

| | Variant A — `modules/router/wan-dhcp.nix` | Variant B — `modules/router/wan-pppoe.nix` |
|---|---|---|
| ONT | still routing | bridged |
| switchboard WAN | DHCP client on the ONT's LAN | PPPoE, public IP |
| NAT | double | single |
| IPv6 | none | DHCPv6-PD `::/56` |
| house WiFi | ONT's own radios | ONT radios re-used as a LAN-side AP |

**Currently deployed: variant B.** It is running and healthy, with `pppd`
looping on `Timeout waiting for PADO packets` because the ONT has not been
bridged yet. That is the expected holding state.

Everything on the NixOS side is done, committed and pushed. The only remaining
work is in the ONT's web UI plus re-cabling.

---

## 2. Topology

### Now (ONT still routing)

```
fibre ── ONT 192.168.2.1 ──┬── LAN1 ── switchboard end1  (waiting for PPPoE)
     (routing, DHCP on)    ├── LAN2 ── LAN switch ── 13 devices on 192.168.2.x
                           └── WiFi GNXS-2.4G / GNXS-5G

switchboard br-lan 192.168.3.1/24 ──┬── end0 ── alcove 192.168.3.2
                                    └── wlan0 ── SSID "switchboard" (2.4GHz)
```

### After cutover

```
fibre ── ONT ── LAN1 ═══════════════ switchboard end1 ── ppp-wan (public IP)
         (bridge, DHCP off,                    │
          LAN IP 192.168.3.254)                │  route + NAT + firewall
                                               │
         ONT LAN2 ── LAN switch ── switchboard end0 ──┴── br-lan 192.168.3.1/24
                          │                            └── wlan0 SSID "switchboard"
                          └── alcove, and everything else
         ONT WiFi ── (bridged onto the LAN via LAN2, becomes a dumb AP)
```

The ONT becomes two unrelated devices in one chassis. **LAN1** is a pure
fibre↔copper media converter upstream of the router. **LAN2 + both radios**
stay in the ONT's own local bridge, bound to no WAN, and become an access point
downstream of the router once LAN2 is patched into the LAN switch. The two
halves must never touch.

---

## 3. Hardware facts

### switchboard — Radxa Cubie A5E

- Allwinner A527, 8 × Cortex-A55 (4 × 1.8 GHz + 4 × 1.4 GHz)
- NixOS 26.11.20260620, kernel 7.0.13, booted from SD card
- Hardware enablement vendored from `github.com/patryk4815/nixos-cubie-a5e`
  under `machines/switchboard/hw-config/`

| Interface | Driver | Role | Why |
|---|---|---|---|
| `end1` | `dwmac-sun55i` @ 4510000 | **WAN** | DWMAC4/5, real DMA capability register, RX mitigation via HW watchdog timer (interrupt coalescing). The stronger MAC, given to the interface taking the highest inbound packet rate. |
| `end0` | `dwmac-sun8i` @ 4500000 | **LAN** | "No HW DMA feature register supported", normal descriptors, chain mode. Weaker. |
| `wlan0` | `aic8800_fdrv` (AIC8800D80 SDIO) | **AP** | out-of-tree vendor driver |
| `usb0` | `g_ether` | recovery | `10.0.0.4/24`, **currently unwired** (`Link detected: no`) |

Both NICs are **single queue with all IRQs on CPU0** — hence RPS and the
nftables flowtable are not optional.

**There is no cpufreq driver.** `/sys/devices/system/cpu/cpu0/cpufreq/` does not
exist. The kernel can neither boost nor throttle; cores run at whatever TF-A
left them at. Thermal sensors exist and read ~45 °C idle, but they are
read-only thermometers with no cooling device attached. The documented A5E
failure mode is throttle → complete shutdown, so cooling is the only protection.

**WiFi firmware is the fixed build.** `fmacfw_8800d80_u02.bin` md5
`56562779b8c4debfd9b354891418249a` = the Dec-2025 `g586bc1e8` blob. The broken
Nov-2023 `g6a92fae` build silently emits zero beacons in 2.4 GHz AP mode. We are
not affected. Verified on-box.

Driver constraints that shaped the config:

- `#{ AP } <= 1` — one AP interface, no multi-BSS, no simultaneous dual-band.
  Multiple SSIDs are impossible on this radio.
- ~50 Mbit/s ceiling in AP mode, 2.4 GHz only in practice.
- A wedged AP does **not** recover from `systemctl restart hostapd`; it needs a
  driver module reload.
- `systemctl is-active` and `tx_packets` both lie. Only a scan with flush from a
  second radio proves beacons are on air.

### alcove — Radxa Cubie A7S

Allwinner A733 (`sun60iw2`), kernel 6.6.98. `end0` on switchboard's LAN
(`192.168.3.2`, pinned by kea reservation), `wlan0` on the ONT's WiFi
(`192.168.2.12`). This is the machine the assistant session runs on.

### ONT — Genexis XC220-G3

AC1200 Wireless XPON router. Web UI plain HTTP at `192.168.2.1`. Interface
Binding page lists `LAN1, LAN2, Wi-Fi_2.4G, Wi-Fi_5G, CWMP`. WAN is PPPoE with
**VLAN disabled** and no MTU field exposed. SSIDs `GNXS-2.4G-179C64` /
`GNXS-5G-179C64`. MAC `3c:52:a1:27:4d:a8`.

---

## 4. The modules

All under `modules/router/`, imported from `machines/switchboard/default.nix`.

### `options.nix`

Declares `router.wanInterface` and `router.ipv6PrefixDelegation`. Exactly one
`wan-*.nix` module must be imported, and it sets both. Everything downstream
(NAT, firewall, MSS clamp, prefix delegation) reads them, so switching variants
is a one-line import change.

Note `router.wanInterface` is the *logical* upstream interface — `ppp-wan` under
PPPoE, `end1` under DHCP. It is deliberately **not** the same as the physical
device the flowtable needs.

### `wan-pppoe.nix` — variant B (currently active)

- `plugin pppoe.so end1` — **not** `rp-pppoe.so`, renamed in ppp 2.5.x
  (nixpkgs#251273)
- credentials via `file ${config.sops.secrets."pppoe.secrets".path}`, because
  `/etc/ppp/peers/isp` is a world-readable store path in a public repo
- `mtu 1492` / `mru 1492`, `persist`, `maxfail 0`, `holdoff 5`, lcp-echo tuning
- `+ipv6 ipv6cp-accept-local`, and deliberately **no `defaultroute6`** — the
  pppd man page warns it conflicts with kernel IPv6 route setup; the v6 default
  route must come from the ISP's RA on the ppp link
- `systemd.services."pppd-isp".before = lib.mkForce [ ]` — the module hardcodes
  `Before=network.target`, which stalls boot ~300 s when the WAN is down
  (nixpkgs#489207)
- `partOf = [ "systemd-networkd.service" ]` — a networkd restart otherwise kills
  the PPPoE session silently
- ppp `.network` has `KeepConfiguration = true` (else networkd wipes pppd's IPv4
  config), `DHCP = "ipv6"`, and `dhcpV6Config.WithoutRA = "solicit"` — the single
  most important DHCPv6-PD setting, because many ISPs never set the RA M/O flag
  and networkd would otherwise wait forever

### `wan-dhcp.nix` — variant A

Plain DHCP client on `end1`, `UseDNS = false`, `RouteMetric = 100`. Sets
`router.ipv6PrefixDelegation = false`, which makes `lan.nix` drop its PD and RA
config via `lib.optionalAttrs`.

### `lan.nix`

`br-lan` = `end0` + `wlan0`, `192.168.3.1/24`.

- `wlan0` deliberately has **no `Bridge=`** in its `.network`. hostapd does the
  enslavement itself; having networkd also claim it while hostapd flips the
  radio station→AP causes races.
- `.network` attribute names are numerically prefixed below 70, because NixOS
  ships `99-*` defaults and the attr name becomes the filename verbatim
  (systemd#34229).
- Explicit `RequiredForOnline` per interface (`enslaved` for bridge ports)
  plus `wait-online.anyInterface` — getting this wrong means two-minute boot
  hangs.
- `networkmanager.enable` and `networking.wireless.enable` are `lib.mkForce
  false`; NM and hostapd would fight over the radio.
- `services.resolved.enable = false` because Pi-hole owns `:53`.

### `nat-firewall.nix`

`networking.nat` with `externalInterface = router.wanInterface` and
`internalInterfaces = [ "br-lan" ]`. The NAT module auto-injects the LAN→WAN
forward accept, so no hand-written forward rules are needed.

Then one `networking.nftables.tables.router` with four constructs:

1. **`chain wan-input`**, priority `filter - 10`, policy accept. Ends with
   `counter drop`. This exists because five services in this config set
   `openFirewall = true` (Pi-hole DNS *and* web, homepage, gatus, netbird,
   tailscale) plus sshd. Rather than unpick five service files, one edge chain
   at lower priority than `nixos-fw` drops everything arriving on the WAN except
   established/related, ICMP (PMTUD and NDP), DHCPv6 client `udp dport 546` and
   DHCP client `udp dport 68`. Pi-hole would otherwise be an **open recursive
   resolver** — a DNS amplification vector.

2. **`chain mss-clamp`**, priority `mangle`, clamping both directions with
   `tcp option maxseg size set rt mtu`. It is a separate table because
   `networking.firewall.extraForwardRules` is appended to `forward-allow`, which
   is only reached from the conntrack vmap on `new`/`untracked`. The outbound
   SYN gets clamped but the returning **SYN+ACK is already `established`** and
   never reaches the chain. There is no NixOS option for MSS clamping.
   `rt mtu` self-adjusts, so the rule is a harmless no-op on a 1500-MTU link.

3. **`flowtable ft`** with `devices = { end1, end0 }` — the **physical** NICs,
   not `ppp0`. Since kernel 5.13 the flowtable finds the real netdevice behind
   PPPoE and VLAN devices and handles L2 decap. This matters a lot: PPPoE RX
   serialises on a socket BH lock in `ppp_input()` (see the Aug-2026 LKML patch
   `pppoe: pass bound packets directly to generic PPP`, which is net-next only
   and therefore not in kernel 7.0). The flowtable hooks at **ingress, before
   `pppoe_rcv()`**, so offloaded flows never touch that lock. Combined with
   single-queue NICs pinning all IRQs to CPU0, this is what makes gigabit
   plausible at all.

4. **`chain flow-offload`**, priority `filter + 10`, doing
   `ct state established,related flow add @ft`. It sits *after* `nixos-fw`'s
   forward chain so only firewall-approved traffic gets offloaded. It cannot be
   named `offload` — that is a reserved nftables keyword and the ruleset fails
   to parse.

Also `networking.nftables.preCheckRuleset` rewrites the flowtable device list to
`{ lo }` for the build-time check. `nft --check` runs under LKL (a userspace
kernel) in the sandbox, which has no `end0`/`end1`. Unlike `iifname`/`oifname`
(strings matched per packet), a flowtable's `devices` list resolves to real
netdevs at ruleset-load time, so the check would fail on a rule that is valid on
the actual box.

### `dhcp.nix`

`services.kea.dhcp4` on `192.168.3.0/24`, pool `.2`–`.240`, gateway and DNS both
`192.168.3.1`, domain `pihole`.

- `interfaces-config.interfaces = [ "br-lan" ]` is the only thing keeping kea off
  the WAN.
- `service-sockets-max-retries = 20` is not optional: the bridge gains carrier
  *after* `network-online.target` fires, and without retries kea opens zero
  sockets and goes permanently deaf.
- Eight reservations, captured from the ONT segment while it was still flat.
  Addresses keep each device's old last octet so the Pi-hole hosts list was a
  straight `s/2\./3./`.
- kea honours reservations **inside** the pool (`reservations-out-of-pool`
  defaults to false), so there is no need to carve out a static block.

Caveat recorded in the file: these NICs have no burned-in MAC. udev's default
`MACAddressPolicy=persistent` derives one from the machine-id and device path.
Stable across reboots, but it moves if either changes, silently dropping a
pinned host back into the dynamic range.

### `tuning.nix`

RPS across the big cores, `netdev_max_backlog=4096`, `netdev_budget=600`, IRQ
pinning, and an `ethtool -K` guard for a documented `dwmac-sun8i` offload
regression where GRO and checksums silently turn off and cost ~10× throughput.
The `ethtool -K` calls are in a per-feature loop because `ethtool -K` is atomic
over its argument list — one unsupported feature rejects all of them, which
would have silently skipped GRO (the highest-value setting, since neither MAC
has TSO/LRO). Also adds `ethtool`, `iw`, `tcpdump`, `conntrack-tools`.

### `modules/wifi/hostapd_ap.nix`

Single 2.4 GHz SSID `switchboard`, `settings.bridge = "br-lan"` (the module has
no `bridge` option and will not create the bridge), PSK from
`sops.secrets."hostapd.psk"`.

- **`channel = 6` hard-pinned, never `0`/ACS.** fullMAC drivers typically lack
  `NL80211_CMD_GET_SURVEY`; hostapd exits with `ACS: Unable to collect survey
  data`.
- **`countryCode` deliberately omitted.** Setting it also emits `ieee80211d=1`,
  which stalls this driver in `COUNTRY_UPDATE` for 90+ seconds whenever the
  requested country differs from the active regdomain — it then "works on the
  second boot", looking like an intermittent bug (radxa-pkg/aic8800#98). The
  kernel command line already carries `cfg80211.ieee80211_regdom=IN`, so IN
  limits are enforced regardless; we just do not advertise the country IE.
- **`wifi4.enable = true`** is worth roughly 4× throughput (49.7/29.7 vs
  12.2/17.3 Mbit/s). hostapd reports `ENABLED` either way.
- **`mode = "wpa2-sha1"` with `settings.ieee80211w = 0`.** ESP8266 has no SAE and
  no PMF at all — searching `ESP8266_RTOS_SDK` for `SAE`, `pmf_cfg`,
  `CONFIG_WPA3_SAE` returns zero hits. The house has ESP8266/ESP32 sensors and
  `imou-*` cameras. WPA3 transition mode is the most-reported breakage point for
  that class of hardware.

---

## 5. Where the secrets are

`machines/switchboard/secrets.yaml`, encrypted to switchboard's SSH host age key,
two YubiKey fido2-hmac recipients, and a PGP key. Relevant entries:

| Key | Used by |
|---|---|
| `pppoe.secrets` | pppd, via the `file` directive |
| `hostapd.psk` | hostapd `wpaPasswordFile` |
| `homepage.env` | homepage-dashboard `environmentFiles` |

**alcove cannot decrypt this file** — it has no PGP secret key and no age
identity. The working procedure is to do it on switchboard itself, which is an
age recipient via its SSH host key:

```sh
scp machines/switchboard/secrets.yaml ritiek@192.168.3.1:/tmp/
ssh ritiek@192.168.3.1
sudo install -d -m 0700 /root/sopswork && cd /root/sopswork
sudo cp /tmp/secrets.yaml .
sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > age.key
sudo SOPS_AGE_KEY_FILE=age.key sops set secrets.yaml '["key.name"]' '"value"'
# copy back, then:  sudo rm -rf /root/sopswork
```

Use `sops set`, not `sops edit` — it preserves the existing recipient list
rather than re-deriving it from `.sops.yaml`, which is not present on the box.
`SOPS_AGE_SSH_PRIVATE_KEY_FILE` is **not** honoured by sops 3.13.1; convert with
`ssh-to-age` first.

The serial console login password is `ff`, plaintext in
`machines/switchboard/default.nix`. That was a deliberate choice, not an
oversight — `mutableUsers = false` and `sudo-rs` with `wheelNeedsPassword =
false`, so serial gives passwordless root immediately.

---

## 6. Cutover procedure

### Before starting

**Join the laptop to switchboard's own AP** — SSID `switchboard`. That gives a
`192.168.3.x` lease and reaches alcove at `192.168.3.2` through
laptop → switchboard radio → `br-lan`, touching no ONT hardware. Verify
`ssh ritiek@192.168.3.2` over it *first*. Without this you go blind from step 2
to step 7, because the laptop moves to `192.168.3.50` while alcove's `wlan0` is
still `192.168.2.12` with no router between them.

While in the ONT UI, toggle that WiFi off — otherwise the laptop has two
interfaces in `192.168.3.0/24` and ONT-bound traffic may leave via the wrong one.

Screenshot the ONT's **WAN**, **LAN**, **Interface Binding** and both **WiFi**
pages. Reverting requires the originals, and bridge mode hides some pages.

### ONT steps

Do these from a laptop wired into **ONT LAN2** with a **static** address. Not
DHCP, not WiFi — you are about to change both DHCP and the ONT's own address.

1. Laptop static `192.168.2.50/24` → browse `http://192.168.2.1`

2. **LAN page**: IP `192.168.3.254`, mask `255.255.255.0`, DHCP server
   **disabled**. Then re-address the laptop to `192.168.3.50/24` and confirm
   `http://192.168.3.254` loads **before continuing**.

   House internet goes down here. Expected — every lease points at a gateway
   that no longer exists. `.254` is outside kea's pool, so nothing collides.

3. **WAN page**: Internet Connect Type PPPoE → **Bridge**. Leave no live PPPoE
   entry behind — two sessions on one credential will flap.

4. **Interface Binding** on that Bridge WAN: check **LAN1 only**. Leave LAN2,
   Wi-Fi_2.4G, Wi-Fi_5G and CWMP unchecked. Everything currently unchecked means
   *unrestricted*, which is exactly what must not happen: it would put WiFi
   clients directly on the PPPoE segment, outside the firewall, with no DHCP
   server.

5. **WiFi pages**: change nothing. Both radios stay enabled on the same SSIDs and
   passwords so nothing in the house re-pairs.

### Re-cable

- ONT `LAN1` → switchboard `end1` — already correct, leave it
- ONT `LAN2` → the LAN switch
- switchboard `end0` → the same switch
- alcove → the same switch (it loses its dedicated cable; switchboard has only
  one LAN port)

---

## 7. Verification

```sh
ssh ritiek@192.168.3.1

journalctl -fu pppd-isp
#  want: "Connect: ppp-wan <--> end1"  then  "local  IP address"
#  bad:  "Timeout waiting for PADO packets"   = bridge not passing PPPoE

ip -br addr show ppp-wan
ping -c3 1.1.1.1
ip -6 addr show br-lan          # expect a global /64 from the delegated prefix
systemctl --failed              # expect empty
```

Prove the AP is genuinely beaconing from a second radio — on this chip
`systemctl is-active` and `tx_packets` both lie:

```sh
nmcli device wifi rescan && nmcli device wifi list | grep switchboard
```

### Abort check

Run on switchboard after re-cabling:

```sh
sudo tcpdump -i end1 -n arp or port 67
```

ARP for `192.168.3.x`, or kea DHCP offers, appearing on `end1` means the ONT is
still bridging LAN1↔LAN2 internally. Your LAN is then exposed on the ISP segment
without passing the firewall. **Unplug ONT LAN2 immediately.** Option (b) is
dead and the fallback is buying one WiFi 6 AP for the LAN switch.

---

## 8. Recovery

### Emergency lever — restores the whole house, no assistant needed

Put the ONT back: WAN to Route/PPPoE (credentials in sops `pppoe.secrets`, also
visible on the ONT's own WAN status page in router mode), DHCP server back on,
LAN IP back to `192.168.2.1`. This works regardless of switchboard's state.

**Rolling back switchboard alone does not restore internet.** The previous
generation expects the ONT to be *routing*. The two changes are coupled.

### Management paths, most to least reliable

1. **Serial console.** From alcove: `, picocom -b 115200 /dev/ttyACM0`, login
   `ritiek`, password `ff`. `/dev/ttyACM0` is world-accessible, so no sudo or
   `dialout` membership needed. Works unless the board is dead.
2. **LAN ethernet**, `ssh ritiek@192.168.3.1`. Works whenever switchboard boots
   and networkd starts. WAN-independent.
3. **U-Boot generation menu** over serial — 5 second timeout, 4 previous
   generations retained (`configurationLimit = 4`).
4. **Tailscale** — only when the WAN is up, so not a recovery path.
5. **`usb0`** at `10.0.0.4/24` — currently unwired, needs a USB-C data cable.

### Offline rollback, no network and no rebuild

```sh
sudo nix-env --profile /nix/var/nix/profiles/system --rollback
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Cannot reach the ONT UI at all

Laptop straight into ONT LAN2, static `192.168.3.50/24`, browse
`192.168.3.254`. Last resort is the reset pinhole, which restores factory router
mode; then re-enter the PPPoE credentials.

---

## 9. Deploying

From alcove:

```sh
cd /etc/nixos
deploy -s --hostname 192.168.3.1 .#switchboard          # live activation
deploy -s --hostname 192.168.3.1 .#switchboard --boot   # stage only
```

`-s` is `--skip-checks`. The node is defined in `flake.nix` with hostname
`switchboard.lion-zebra.ts.net`, so `--hostname` is required whenever Tailscale
is down.

**Live activation fails while switchboard has no WAN**: `tailscaled-autoconnect`
times out at 90 s and deploy-rs treats that as an activation failure, then rolls
back. Until PPPoE is up, use `--boot` followed by `sudo systemctl reboot`.

Reboot takes ~90 s and looks alarming over serial: this board's TF-A has no PSCI
`SYSTEM_RESET`, so shutdown deliberately crashes the kernel and waits ~15 s for
the hardware watchdog.

---

## 10. Known risks and things never measured

- **No cpufreq driver.** The kernel cannot throttle. Cooling is the only
  protection and the documented A5E failure mode is throttle → shutdown.
- **Throughput was never benchmarked.** Hardware validation was explicitly
  dropped. The first real load test is production. Comparable A55 hardware
  (NanoPi R5S, RK3568) does 2.36 Gbit/s NAT'd *with* flow offload; without it,
  extrapolation puts this class right at the gigabit line. This board is weaker:
  slower cores, on-SoC DWMAC, single queue, no TSO.
- **Cold-boot NIC race never reproduced** here, but was also never power-cycle
  tested. Upstream reports `-110 deferred probe timeout` on the second NIC
  requiring a warm reboot. Worth 5–10 power cycles before trusting it.
- **WiFi is one 2.4 GHz SSID at ~50 Mbit/s.** The driver allows exactly one AP
  interface. This is why re-using the ONT's radios matters.
- **VLANs are deliberately deferred.** They were a stated requirement, dropped
  only for lack of hardware: one LAN port, one AP interface, no managed switch.
  When a managed switch arrives, `br-lan` gains `VLANFiltering` and the LAN port
  becomes a hybrid trunk.

---

## 11. Outstanding

- Flip the ONT to bridge mode (this document, section 6)
- Lower alcove's `end0` route metric once the ONT's WiFi is no longer its primary
  path
- **pilab advertises `192.168.2.0/24` over Tailscale**, imperatively — it is not
  in this repo, only in pilab's live `tailscale debug prefs`. It hijacks traffic
  to that subnet at metric 0 and has already caused two rounds of confusing
  routing. pilab even carries its own workaround for it at
  `machines/pilab/default.nix:506`. The clean fix is to stop advertising it.
- `machines/pilab/home/ritiek/services/dns-resolution/routers/tplink.py` scrapes
  a router at `192.168.2.1` for DHCP leases; obsolete once kea owns the subnet
- Pi-hole hosts list has a pre-existing duplicate: `.14` is both
  `robotic-arm-esp32` and `mishy`
- Two Pi-hole entries are commented out — `redmi-note-11` (no reservation; it was
  not associated during the MAC sweep, and its old address had drifted onto
  switchboard's own WAN interface) and `pilab-wlan` (pilab answers on two
  addresses from one MAC, so only one reservation is possible)
- `users.users.ritiek.password = "ff"` is plaintext in a public repo. Deliberate
  for now; `hashedPasswordFile` backed by sops is the fix.

---

## 12. Commit history

```
6794deb  switchboard: prepare the PPPoE cutover
e5d093c  switchboard: drop pihole's declarative lists, add a gravity timer
9930716  switchboard: widen the DHCP pool, pin alcove at 192.168.3.2
3dc9e9a  switchboard: move the LAN to 192.168.3.0/24, WAN via DHCP
65b093a  switchboard: turn into the household router
95d74a4  switchboard: run pihole, homepage and gatus natively
```

Each commit message carries the reasoning for its own change. `git log` is the
other half of this document.
