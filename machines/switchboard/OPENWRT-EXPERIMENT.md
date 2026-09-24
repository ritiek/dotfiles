# OpenWrt on Radxa Cubie A5E — Experiment Handoff

**Status:** research complete, nothing built or flashed yet.
**Intent:** *experiment only.* The user wants to try OpenWrt on the Cubie A5E
board out of curiosity. This is explicitly **not** a migration off NixOS. The
production NixOS setup must remain untouched and instantly restorable.
**Date of research:** 2026-08-22.

---

## 0. How to read this document

Sections 1–3 are context (what the board is, what it currently does).
Sections 4–6 are the two real blockers and their solutions.
Section 7 is the recommended plan. Section 8 is verification. Section 9 is
rollback. Section 10 lists what is *unproven* — read it before promising
anything to the user.

The single most important finding is in **§6**: the WiFi driver port is far
more tractable than it first appears, because an OpenWrt package already
exists that builds from the *exact same upstream commit* this repo pins.

---

## 1. Environment and access

| Machine | Role | Arch | Notes |
|---|---|---|---|
| `alcove` | **where you are now**; build host | aarch64, 8 cores, 5.8 GiB RAM, ~70 GB free on `/` | Has `/etc/nixos` checked out on branch `main`. Hosts an `atticd` binary cache on `:7080`. |
| `switchboard` | the Cubie A5E under test | aarch64 (Allwinner A527) | LAN gateway `192.168.3.1`. |

Network topology (double-NAT, deployed and verified 2026-08-22):

```
internet ── ONT (routes + NATs 192.168.2.0/24, gateway .1)
              ├── switchboard  end1 = 192.168.2.12  (plain DHCP client)
              │     └── switchboard LAN: br-lan = 192.168.3.1/24 (2nd NAT)
              │           ├── end0  (wired)
              │           └── wlan0 (SSID `switchboard`, 2.4 GHz ch 6)
              └── alcove wlan0 = 192.168.2.4
```

`alcove` sits on **both** segments — `end0` = `192.168.3.15` (switchboard's
LAN) and `wlan0` = `192.168.2.4` (ONT's WiFi).

Switchboard is still actively running this full double-NAT stack (pihole, kea
DHCP, hostapd AP, gateway) — it has **not** been taken out of service. The
user has explicitly said **not to worry about downtime**: go ahead and
experiment without arranging a maintenance window or coordinating outages.
Section 3 below still documents what runs on it, purely so you know what
you're looking at in `systemctl status` — not as a reason to hold back.

**Primary access method — Tailscale hostname (works from anywhere, including
off-LAN):**

```sh
ssh ritiek@switchboard.lion-zebra.ts.net
```

Confirmed reachable 2026-08-22 (Tailscale on switchboard had been down earlier
in this project's history during an unrelated router-cutover experiment; it
is back up now). This is the method to default to.

**Fallback — direct LAN IP, only works if you are physically on switchboard's
LAN segment** (e.g. from `alcove`'s `end0`, which sits on `br-lan`):

```sh
ssh ritiek@192.168.3.1
```

This will simply time out from anywhere not on that L2 segment (confirmed:
times out from a machine on the ONT's WiFi instead). Note alcove's own SSH key
was historically **not** authorized on switchboard — if this prompts for a
password or is refused even from alcove, add alcove's key to
`machines/switchboard/default.nix` (the `users.users.ritiek.openssh.
authorizedKeys.keys` list) and redeploy, or use agent forwarding.

Repo state at handoff (`/etc/nixos`, branch `main`, HEAD `7896d68 "Sync up"`):

```
 M machines/switchboard/CUTOVER.md
?? .playwright-mcp/
?? investigation.md
?? network.md
?? success_login.md
```

**Do not read or act on `network.md`, `success_login.md`, `investigation.md`,
or `.playwright-mcp/`.** These are stale scratch files from an abandoned
ONT-bridge-mode experiment. The user explicitly instructed to ignore them
entirely and not to delete them. They are unrelated to this task.

Also per explicit user instruction: **bridging the ONT is off the table
permanently.** Do not propose it. The ISP MAC-locks the account and this ONT's
firmware has no usable bridge mode.

---

## 2. Board identity — verified on hardware

| Property | Value | How confirmed |
|---|---|---|
| Model | Radxa Cubie A5E | `/proc/device-tree/model` |
| SoC | Allwinner **A527** (`sun55iw3` die; shared with A523/T527/H728) | linux-sunxi.org |
| RAM | **938 MiB usable → this is the 1 GB variant** | `free -h` |
| Kernel (NixOS) | **7.0.13** | `uname -r` |
| Root storage | **microSD card** | closure name `nixos-system-switchboard-sd-card-…` |
| Boot firmware | mainline U-Boot + TF-A, already flashed to **16 MiB SPI NOR** | `hw-config/uboot.nix` |
| WiFi/BT module | LB-Link BL-M8800DS2 → **AIC8800D80** chip, **SDIO** bus (`mmc1:390b:1`) | `lsmod`, `aic_fw_path=…/aic8800D80` |
| Ethernet | 2× 1 GbE (MAXIO MAE0621A PHYs, one PoE-capable) | board docs |
| M.2 | M-key 2230, 1× PCIe 2.1 lane, **muxed with USB 3.0 via GPIO** (one or the other, never both) | `hw-config/cubie-a5e.nix` |
| PMICs | AXP717 + AXP323 | board docs |

**The 1 GB variant is the single most consequential fact in this document.**
See §5.

`lsmod` on switchboard confirms the WiFi stack:

```
aic8800_fdrv      782336  0
cfg80211         1245184  3 mac80211,rtl8xxxu,aic8800_fdrv
aic8800_btlpm      12288  0
aic8800_bsp       176128  2 aic8800_btlpm,aic8800_fdrv
```

Note it binds **`cfg80211` directly, not `mac80211`** — it is a fullMAC
vendor driver. (`mac80211`/`rtl8xxxu` are present for an unrelated USB
dongle.) This matters for OpenWrt integration; see §6.3.

---

## 3. What switchboard currently does — i.e. what OpenWrt would displace

This is a fully-featured, currently-running double-NAT router (§1). Listed
here purely as an observability reference — so `systemctl status` / `lsmod`
output makes sense to you, and so you know what a client on `192.168.3.0/24`
would notice disappear. **The user has explicitly said downtime doesn't
matter for this experiment — this is not a reason to hold back or schedule
around.**

- **Routing/NAT** — `modules/router/nat-firewall.nix`. `wanPhys=end1`,
  `lanPhys=end0`, `lanBridge=br-lan`. `filterForward = true` (FORWARD default
  drop). Custom nftables chains: `wan-input` (drops all unsolicited inbound on
  WAN except icmp/established/related/DHCP — deliberately **no port
  forwarding**, remote access is via Tailscale/Netbird only), `mss-clamp`
  (self-adjusting via `rt mtu`), and a `flowtable ft` + `flow-offload` chain.
  **Software flow offload is documented as mandatory on this hardware**
  (single-queue NICs, all IRQs pinned to CPU0, no cpufreq driver).
- **DHCP** — `modules/router/dhcp.nix`, kea DHCPv4 on `br-lan` only, subnet
  `192.168.3.0/24`, pool `.2–.240`, hands out router+DNS = `192.168.3.1`, with
  ~8 static reservations (alcove `.2`, pilab `.8`, ritiek-edra-m2 `.9`,
  alcove-wlan `.12`, phillips-air-purifier `.13`, robotic-arm-esp32 `.14`, two
  switches `.4`/`.5`).
- **DNS / ad-blocking** — `services/pihole.nix` (231 lines). Native
  `pihole-ftl` + `pihole-web` owning port 53. Upstreams 1.1.1.1/1.0.0.1. Large
  static hosts list, cnameRecords → `*.lion-zebra.ts.net`, plus a custom
  `pihole-gravity` service + weekly timer that replaces broken upstream list
  seeding.
- **WiFi AP** — `modules/wifi/hostapd_ap.nix`. SSID `switchboard`, 2.4 GHz,
  channel 6. Serves the ESP8266/ESP32 sensor fleet and `imou-*` cameras.
- **Overlay VPNs** — Tailscale (`modules/tailscale-controlplane.nix`,
  **self-hosted control plane** at `https://controlplane.clawsiecats.omg.lol`,
  Headscale-style, *not* tailscale.com; switchboard = `100.64.0.14`) and
  Netbird (`modules/netbird.nix`, client `birdnet`, interface deliberately
  renamed to **`wt0`** to dodge Tailscale's `isProblematicInterface` logic
  which otherwise caused WireGuard-over-WireGuard throughput collapse).
- **Services** — `homepage-dashboard`, `gatus`, `usbipd`.

**Practical note (informational, not a blocker):** while switchboard runs
OpenWrt, the house loses DNS, DHCP, WiFi, and its internet gateway from this
box — again, confirmed fine with the user. If it's convenient, doing the
first boot with switchboard's LAN cable unplugged and a laptop wired straight
into `end0` avoids any confusion about which device is answering DHCP, but
that's a convenience, not a requirement.

---

## 4. OpenWrt upstream status

Support for this exact board exists as **PR
[openwrt/openwrt#23296](https://github.com/openwrt/openwrt/pull/23296)** —
*"sunxi: add support for A527/T527 boards"*.

| | |
|---|---|
| Author | **wigyori** (Zoltan Herpai) — the OpenWrt **sunxi target maintainer** |
| Opened | 2026-05-11 |
| Last updated | 2026-08-21 (actively worked, not abandoned) |
| State | **open**, `mergeable_state: blocked` |
| Size | 4 commits, 60 files, +12332 / −12 |
| Kernel | **6.18** |
| Boards | **Radxa Cubie A5E**, Avaota A1 |

What it adds:
- a new `target/linux/sunxi/cortexa55/` subtarget (`target.mk`, `config-6.18`)
  and `target/linux/sunxi/image/cortexa55.mk`
- `package/boot/uboot-sunxi/uEnv-a523.txt`
- 8 TF-A patches (`0001`–`0008`, ending in
  `0008-feat-allwinner-add-A523-support.patch`)
- ~45 kernel patches in `target/linux/sunxi/patches-6.18/`, notably:
  - `001`–`004` — GMAC200, enabling the **second Ethernet** on cubie-a5e
  - `102`–`106` — the **same A523 THS0/1 thermal series this repo already
    vendors** (see §11)
  - `402`–`407` — SPI / SPI-NOR
  - **`701-Add-wifi-mmc1-to-Radxa-Cubie-A5E.patch`** — enables mmc1/SDIO1 for
    WiFi (**device-tree only, no driver**) — see §6
  - **`702-Enable-uart1-bluetooth-on-Radxa-Cubie-A5E.patch`**
  - `804`–`813` — IOMMU, PCIe RC, USB3 combo-PHY, AC200 EPHY

**Why it is still open:** reviewer `aiamadeus` objected that (a) the kernel
patches should be one commit with backports renumbered per
`target/linux/generic/PATCHES.md`, and (b) putting Cortex-A55 parts into a
CPU-specific subtarget is wrong — it should be a generic `armv8` subtarget
like rockchip/armv8. wigyori agreed, spun off prerequisite PR
**[#23410](https://github.com/openwrt/openwrt/pull/23410)**, and said *"Will
rework this PR once the above is merged."* An openwrt[bot] check still flags
`901-…patch` for missing `git am` headers.

**→ Expect to rebase.** The branch will be restructured. Pin a specific merge
commit locally so your build is reproducible.

**Independent confirmations it works:**
- `mamunpro01` (2026-07-27): *"I build your PR and i'm currently using it in
  my 2GB & 4GB varient, I also install third-party some package and it's
  working perfectly"* (with LuCI screenshot)
- `mama420` (2026-08-06): *"I successfully build img for my cubie a5e and
  currently runnig without any issues."*
- OpenWrt forum thread
  [t/243663](https://forum.openwrt.org/t/243663): after cherry-picking the
  GMAC1 patches, *"OpenWrt 25.12.0-rc4 (r32534-12374d88b9) boots on A5E and
  both nics bring up links."* `iuncuim` publishes prebuilt A5E images there.

Note **every** success report is from a **2 GB or 4 GB** board. See §5.

Release context: OpenWrt stable is **25.12.5** (1 Jul 2026); old-stable
24.10.8. This PR targets `main` with kernel 6.18 — **not in any release.**

---

## 5. Blocker 1 — the 1 GB variant does not boot on stock U-Boot

Upstream is explicit. Reviewer `aiamadeus` on PR #23296:

> *"missing drivers such as CPUFREQ, PCI/USB3, and memory issues… Memory
> issue: The board with 1 GB of RAM is unable to boot."*

and when asked whether the 2026.04 U-Boot bump fixed it:

> *"Yes, this problem may not be able to be solved for the time being."*

**Root cause** (Armbian forum, *"RADXA Cubie A5E 1GB RAM Armbian CLI stucks
while uboot via sdcard"*): the 1 GB / 2 GB / 4 GB SKUs use **different DRAM
chips at different voltages** (2/4 GB run 0.6 V). Stock SPL hangs immediately
after printing `DRAM: 1024 MiB`. A related 1 GB log shows `Failed to set core
voltage! Can't set CPU frequency`. User `Guation` fixed it with hand-tuned
DRAM parameters (`Guation/radxa-cubie-a5e-armbian-build`, commit
`202f1bf3943e2a583e10405f54b206fae9991a98`) but as of ~2026-08-19 has
**deliberately not upstreamed it**, wanting to first check whether the params
can be unified across SKUs.

### This is already solved on this board

Critically, **this is a U-Boot/SPL-stage problem, not a kernel problem** — and
`machines/switchboard/hw-config/uboot.nix:84-90` already carries a working
1 GB DRAM tuning, which is **already flashed to the board's SPI NOR**:

```
CONFIG_DRAM_SUNXI_TPR2=0x1f0b0503
CONFIG_DRAM_SUNXI_TPR6=0x3a000000
CONFIG_DRAM_CLK=720
CONFIG_DRAM_SUNXI_TPR10=0x802f3333
CONFIG_DRAM_SUNXI_TPR11=0xc0c0bbbf
CONFIG_DRAM_SUNXI_TPR12=0x35352f31
```

(`mainline-1gb` differs from `mainline-2gb` by *nothing else*.)

So OpenWrt's **kernel** can boot here. The danger is only OpenWrt's **own
SPL**, which ships at the front of its sunxi SD images and carries the
unfixed 2/4 GB params. Sunxi BROM probes **SD before SPI NOR**, so a
stock OpenWrt SD image would run its own broken SPL and hang.

**Two ways around it:**

- **(a) Preferred — rebuild OpenWrt's `uboot-sunxi` with the params above.**
  Cleanest and self-contained; the image then boots standalone.
- **(b) Quick hack — zero the SPL region at the front of the OpenWrt SD image**
  so the BROM falls through to the known-good SPI NOR U-Boot, which then loads
  OpenWrt's kernel from the SD. Requires OpenWrt's boot script
  (`uEnv-a523.txt` / `boot.scr`) to be reachable by that U-Boot's boot
  targets — verify, don't assume.

Option (b) is faster for a first smoke test; option (a) is what you want if
the experiment continues.

### FEL recovery — read this before flashing anything

If SPI NOR gets clobbered, recovery is documented in `flake.nix:310-330`:

```sh
nix run .#sunxi-fel -- ver          # expect soc=00001890(A523)
nix run .#sunxi-fel -- spl uboot-1gb.bin write 0x50000000 spinor-1gb.img exe 0x4a000000
# then, from U-Boot's UART console at 115200:
#   sf probe && sf update 0x50000000 0 0x1000000 && reset
```

FEL is entered with no SD inserted and no valid eGON signature on SPI; there
is a dedicated FEL button. The USB-C port carries the OTG signals, so the
board must be powered from a host or powered hub. Note `sunxi-fel
spiflash-write` has **no A523 support** — hence the two-stage dance above.

**A serial console at 115200 is mandatory for this work.** With no WiFi driver
initially and possibly no boot, it is the only diagnostic channel.

---

## 6. Blocker 2 — WiFi — and why it is very solvable

### 5.1 Why it looks hopeless at first

The chip is an **AIC8800**, which has no mainline driver and never will.
OpenWrt core dev `slh`, on the forum:

> *"wifi will 'never' work properly, there's no one working on a mainline
> driver for aic8800."*

A code search for `aic8800 org:openwrt` returns **0 results** — nothing in the
OpenWrt tree. PR #23296's patches `701`/`702` add **device-tree nodes only**;
they wire up the SDIO and UART buses but ship no driver.

### 5.2 Why it is actually fine — the key finding

**An OpenWrt package for this driver already exists, built from the *exact
same upstream commit this repo pins*.**

[`firtel-t/aic8800-sdio-openwrt`](https://github.com/firtel-t/aic8800-sdio-openwrt):

```make
PKG_NAME:=aic8800-sdio
PKG_VERSION:=5.0
PKG_SOURCE_URL:=https://github.com/radxa-pkg/aic8800.git
PKG_SOURCE_VERSION:=7f42b22913b462ab6c658dfc075bae1dbfe9a71a
PKG_SOURCE_DATE:=2026-04-29
```

`machines/switchboard/hw-config/aic8800-sdio.nix:19-24`:

```nix
src = fetchFromGitHub {
  owner = "radxa-pkg";
  repo = "aic8800";
  rev = "7f42b22913b462ab6c658dfc075bae1dbfe9a71a";
  hash = "sha256-WaFE8nwFHn4ws+kLhhWZgrFOQHfJ5ByaEjpfjpv131s=";
};
```

**Identical commit.** And it lines up on every other axis:

| | This repo (NixOS) | firtel-t (OpenWrt) |
|---|---|---|
| Chip | AIC8800**D80** | AIC8800**D80** |
| Bus | SDIO | SDIO |
| Modules | `aic8800_bsp`, `aic8800_fdrv`, `aic8800_btlpm` | `aic8800_bsp`, `aic8800_fdrv` (btlpm off) |
| Deps | `cfg80211`, mmc | `+kmod-cfg80211 +kmod-mmc` |

The package's `AUTOLOAD` is `AutoProbe aic8800_bsp aic8800_fdrv`; firmware is
installed to `/lib/firmware/aic8800_fw/SDIO/aic8800D80/`.

Other ports exist too — `BrelJordan/aic-wifi-openwrt` (SDIO, Radxa 5C),
`kasonhaimen/openwrt-aic8800dc`, `nickbash11/aic8800-usb_openwrt`,
`z1015161472-dotcom/aic8800-openwrt-driver`, `simon-lee-1/aic8800-openwrt-bt`.
This is a well-trodden path, not a research project.

**So the pieces compose:**
`PR #23296` (board + DT/mmc1) **+** `firtel-t` package (driver) **+** firmware
**= working WiFi.** Out-of-tree kmod packages are the normal OpenWrt mechanism
for exactly this; `brcmfmac` is precedent that fullMAC cfg80211 drivers
integrate fine with netifd and hostapd.

### 5.3 Kernel 6.18 compatibility resolves for free

`radxa-pkg/aic8800` maintains a cumulative, `LINUX_VERSION_CODE`-guarded
patch series in `debian/patches`:

```
6.1  6.5  6.7  6.9  6.13  6.14  6.15  6.16  6.17   ──►  6.19  7.1  7.2
                                              ▲
                            no 6.18 patch — the series skips it
```

**There is no 6.18 patch, because 6.18 needs nothing beyond 6.17.** OpenWrt's
A5E PR uses exactly 6.18. This is the single luckiest fact in the whole
investigation.

Plus non-version patches you want: `fix-sdio-firmware-path.patch`,
`fix-sdio-fall-through.patch`, `fix-vmalloc-not-include.patch`,
`fix-debug-file-with-no-debug-symbols.patch`. There is also
`fix-build-on-low-memory-devices-v2.patch` — possibly relevant given alcove
has 5.8 GiB RAM.

firtel-t's `download-patches.sh` already fetches precisely this set (numbered
`010`–`140`). Because the patches are version-guarded, applying the whole
series is the normal DKMS-style approach and should be safe — **but verify the
guards rather than assuming.**

> **This repo's `hw-config/patches/aic8800-kernel-7.0.patch` (22.7 K, applied
> with `-p6`) is NOT needed for OpenWrt.** It was a local stopgap written when
> upstream had no 7.0 patch; upstream now ships 7.1/7.2 instead. OpenWrt's
> 6.18 is *older*, so that patch would only conflict. Ignore it — but it is a
> useful reference if you hit an API break.

### 5.4 Driver defects that follow you regardless

None of these are OpenWrt's fault; they are firmware/driver limitations
already documented in `modules/wifi/hostapd_ap.nix`. Carry the workarounds
across:

| Defect | Existing workaround |
|---|---|
| **No ACS** — driver never answers `NL80211_CMD_GET_SURVEY`; hostapd dies with *"ACS: Unable to collect survey data"* | **Pin the channel.** OpenWrt defaults to `channel=auto` — you *must* set an explicit channel in `/etc/config/wireless`. NixOS pins ch 6. |
| **Country-code stall** — `ieee80211d=1` hangs hostapd 90+ s in COUNTRY_UPDATE (radxa-pkg/aic8800#98) | Don't set country in hostapd. Pass `cfg80211.ieee80211_regdom=IN` as a **kernel param** instead. |
| **Single BSS, no multi-SSID** | One SSID only. No separate IoT/guest network on this radio. |
| **No AP + STA concurrently** | `iw list` advertises it; the firmware does not honor it. AP-only. This is why the board needs the wired `end1` uplink. |
| **Single radio — 2.4 GHz *or* 5 GHz, not both** | `phy0` genuinely supports both bands (2412–2484 and 5180–5825), but only one AP interface exists. Concurrent dual-band needs a second physical radio. |
| **No WPA3/802.11w** | The ESP8266/ESP32 fleet and `imou-*` cameras lack SAE. Use WPA2-CCMP, `ieee80211w=0`. |
| HT40 broken | Driver emits `[HT40]`; hostapd wants `[HT40+/-]`. Use `SHORT-GI-20` only (still ~4× throughput: 49.7/29.7 vs 12.2/17.3 Mbit/s). |

### 5.5 Bluetooth (optional, low priority)

PR patch `702` enables uart1. NixOS attaches BT with
`hciattach /dev/ttyS1 any 1500000 flow` (see `aic8800-sdio.nix:156-168`).
firtel-t's package disables `aic8800_btlpm`. Skip BT for the experiment.

---

## 7. Recommended plan

The user confirmed this is **an experiment**. Therefore: **sequence it to fail
fast.** Prove the board boots OpenWrt at all *before* investing in driver
packaging — the 1 GB DRAM issue (§5) is the likeliest hard stop, and it is
cheap to test.

### Phase 0 — Preparation (no risk)
1. Obtain a **spare microSD**. The NixOS install lives on the current card, so
   card-swapping is the entire rollback story. Do not reuse the production card.
2. Attach a **serial console** (115200 8N1) and confirm you can see U-Boot
   output. Do not proceed without this.
3. Confirm the FEL recovery path in `flake.nix:310-330` is understood and the
   `spinor-1gb.img` artifact is buildable (`nix build .#switchboard-spinor-1gb`).
4. Downtime is fine — the user has explicitly said not to worry about it, so
   no maintenance window is required. (§3 still lists what's running so you
   know what disappears while the board is on OpenWrt: DNS, DHCP, WiFi AP,
   gateway. Just don't block on it.)

### Phase 1 — Boot OpenWrt with Ethernet only (the real go/no-go)
5. Clone `openwrt/openwrt`, fetch PR **#23296** (and **#23410** if it has
   become a prerequisite). **Pin the exact commit you build from** and record
   it here, since the branch will be rebased.
6. Solve the 1 GB SPL problem per §5 — option **(a)** rebuild `uboot-sunxi`
   with the six `CONFIG_DRAM_*` values, or **(b)** strip the SD SPL to fall
   through to SPI NOR.
7. Build for the `cortexa55` sunxi subtarget. **No WiFi package yet.** Cap
   parallelism — alcove has 8 cores but only 5.8 GiB RAM; `make -j4` is safer
   than `-j8`, and OpenWrt buildroot wants ~25–50 GB (70 GB free, fine).
8. Flash to the spare SD, boot, watch serial.
9. **Decision gate.** If it does not get past `DRAM: 1024 MiB`, the 1 GB issue
   is unsolved for OpenWrt's SPL — go back to step 6 option (b), and if that
   also fails, report back before sinking more time. If it boots to a shell
   with both NICs up, continue.

### Phase 2 — WiFi
10. Add a custom package feed with an `aic8800-sdio` package. Start from
    firtel-t's `Makefile` verbatim (§6.2), then:
    - run its `download-patches.sh` to pull the radxa-pkg series;
    - **verify the version guards** so the 6.19/7.1/7.2 patches no-op on 6.18
      (drop them if not);
    - **check the firmware install path.** firtel-t installs to
      `/lib/firmware/aic8800_fw/SDIO/aic8800D80/`, while this repo's driver is
      told `aic_fw_path=…/firmware/aic8800/aic8800D80`. Confirm which path the
      built module actually probes (`fix-sdio-firmware-path.patch` is what sets
      it) and make them agree, or pass `aic_fw_path` explicitly.
11. Rebuild with `kmod-aic8800-sdio` + firmware package selected.
12. Configure `/etc/config/wireless` with an **explicit channel** and WPA2-CCMP
    (§6.4). Add `cfg80211.ieee80211_regdom=IN` to the kernel cmdline.

### Phase 3 — Report
13. Write findings back into this file. If the experiment ends, swap the
    NixOS card back in (§9) and confirm the house is healthy.

**Do not** attempt to reproduce switchboard's full service stack (pihole, kea,
Tailscale, Netbird, homepage, gatus) on OpenWrt. That is out of scope for an
experiment and the user has not asked for it.

---

## 8. Verification checklist

Work down this list in order; each step gates the next.

**Boot**
- [ ] Serial shows SPL past `DRAM: 1024 MiB` (this is the 1 GB gate)
- [ ] TF-A + U-Boot banner
- [ ] Kernel boots to an OpenWrt shell
- [ ] `dmesg | grep -i sunxi` — no PHY/clk explosions

**Ethernet**
- [ ] Both NICs enumerate (`ip link` shows two ethernet devices)
- [ ] Both bring up carrier at 1 Gbps FDX
- [ ] DHCP lease on the WAN-facing NIC; `ping 1.1.1.1` succeeds
- [ ] Watch specifically for `dwmac-sun55i … Unable to map syscon` /
      `probe … failed with error -22`, the known GMAC1 failure mode

**WiFi (Phase 2)**
- [ ] `dmesg | grep -i aic` — firmware loads, no path errors
- [ ] `iw phy` shows a wiphy with both bands
- [ ] `wifi detect` populates `/etc/config/wireless`
- [ ] AP starts on the **pinned** channel (if it hangs ~90 s, suspect the
      country-code bug — §6.4)
- [ ] A 2.4 GHz client associates and gets an IP
- [ ] Sanity-check throughput vs. the NixOS baseline (49.7/29.7 Mbit/s with
      `SHORT-GI-20`)

**Housekeeping**
- [ ] Record the exact OpenWrt commit, PR revision, and any local patches
- [ ] Note anything that had to be changed vs. this document

---

## 9. Rollback

Rollback is **swapping the microSD card**, because NixOS lives entirely on the
production card (`nixos-system-switchboard-sd-card-…`).

1. Power off the board.
2. Remove the OpenWrt card, reinsert the NixOS card.
3. Power on.
4. Verify: `end1` gets `192.168.2.x`; `systemctl --failed` is empty;
   `ping 1.1.1.1` works; `pihole-ftl` is active and resolving;
   `tailscale status` shows switchboard back on the tailnet; a LAN client gets
   a `192.168.3.x` lease with DNS `192.168.3.1`; SSID `switchboard` is up and
   the IoT fleet reconnects.

**The one way to make this non-reversible is to overwrite SPI NOR.** SPI NOR
holds the working 1 GB U-Boot that *both* systems depend on. Prefer §5
option (a) (build OpenWrt's U-Boot for SD) over reflashing SPI NOR. If SPI NOR
must be touched, build and keep `nix build .#switchboard-spinor-1gb` on hand
first, and know the FEL procedure (§5).

Reference deploy command if NixOS needs redeploying (adjust for running from
alcove — no jump host needed on-LAN):

```sh
nixos-rebuild switch --flake /etc/nixos#switchboard \
  --target-host ritiek@192.168.3.1 --build-host ritiek@192.168.3.1 \
  --option extra-substituters "http://192.168.3.15:7080/attic-action" \
  --use-remote-sudo
```

---

## 10. Known unknowns — be honest with the user about these

1. **No one has run aic8800 on OpenWrt on *this SoC*.** Every existing SDIO
   port targets Rockchip (RK3566/RK3568). The driver is bus-generic SDIO so it
   *should* be portable, but Allwinner mmc1 + this driver under OpenWrt is
   genuinely untested. Moderate confidence, not certainty.
2. **No 1 GB board has been reported booting OpenWrt.** All PR success reports
   are 2 GB/4 GB. The SPI NOR U-Boot workaround is sound reasoning but
   unproven for this combination.
3. **PR #23296 will be rebased** into a restructured subtarget. Anything built
   now needs rework later.
4. **No cpufreq/DVFS driver** for A523 — measured ~56 sysbench events/sec
   single-thread, no `/sys/devices/system/cpu/cpu*/cpufreq` at all. **Not an
   OpenWrt regression** — NixOS has the same limitation and sets
   `cpuFreqGovernor = "performance"` regardless. Mention it only so it isn't
   mistaken for a new problem.
5. **No PSCI SYSTEM_RESET** in the WIP TF-A. NixOS works around this with a
   `watchdog-reboot-helper` service that deliberately panics the kernel
   (`echo c > /proc/sysrq-trigger`) on shutdown, relying on the hardware
   watchdog to reboot. **OpenWrt has no such workaround** — expect `reboot` to
   hang the board and require a power cycle.
6. **PCIe/USB3 are muxed** (`hardware.cubie-a5e.combophy`, GPIO-controlled).
   Only one is usable at a time; the OpenWrt PR's `804`–`813` patches cover
   the drivers but the mux selection is a separate concern.

---

## 11. Reference map

**In this repo**

| Path | Why it matters |
|---|---|
| `machines/switchboard/hw-config/uboot.nix:84-90` | **The 1 GB DRAM params.** The crown jewels for §5. |
| `machines/switchboard/hw-config/aic8800-sdio.nix` | Working driver packaging: source pin, build flags (`CONFIG_PLATFORM_UBUNTU=y`, `CONFIG_PLATFORM_ALLWINNER=n`), firmware layout, `aic_fw_path`, `aicwf_dbg_level=1` (the vendor default 1039 floods a 115200 UART — set this early). |
| `machines/switchboard/hw-config/patches/aic8800-kernel-7.0.patch` | **Not needed for OpenWrt** (§6.3), but a reference for API breaks. |
| `machines/switchboard/hw-config/wifi-overlay.dts` | What PR patch `701` duplicates (mmc1 enable). |
| `machines/switchboard/hw-config/cubie-a5e.nix` | The 11 out-of-tree kernel patches (5 thermal from `iuncuim@gmail.com`, 5 PCIe/combophy from Armbian) and the watchdog-reboot workaround. |
| `machines/switchboard/hw-config/{spi-nor,usb3}-overlay.dts`, `disko.nix` | Storage/mux layout. |
| `flake.nix:310-330` | **FEL recovery procedure.** |
| `flake.nix:341-348` | `switchboard-uboot-1gb`, `switchboard-spinor-1gb` outputs. |
| `machines/alcove/aic8800-usb.nix` | Sibling USB-variant packaging; useful precedent. |
| `modules/wifi/hostapd_ap.nix` | **The definitive catalogue of this radio's defects and workarounds.** Read before configuring WiFi on OpenWrt. |
| `machines/switchboard/CUTOVER.md` | Router cutover history (currently has uncommitted edits). |

**External**

- PR: https://github.com/openwrt/openwrt/pull/23296
- Prerequisite PR: https://github.com/openwrt/openwrt/pull/23410
- Forum thread (prebuilt images, GMAC1 fix): https://forum.openwrt.org/t/243663
- Driver source: https://github.com/radxa-pkg/aic8800
  (pin `7f42b22913b462ab6c658dfc075bae1dbfe9a71a`; patches in `debian/patches`)
- OpenWrt package to copy: https://github.com/firtel-t/aic8800-sdio-openwrt
- Other ports: `BrelJordan/aic-wifi-openwrt`, `kasonhaimen/openwrt-aic8800dc`,
  `nickbash11/aic8800-usb_openwrt`
- 1 GB DRAM fix (not upstreamed): `Guation/radxa-cubie-a5e-armbian-build`
  @ `202f1bf3943e2a583e10405f54b206fae9991a98`
- SoC status: https://linux-sunxi.org/A523

**A523 mainline timeline** (for judging what needs backporting): base support
v6.15, DTs v6.16, **GMAC1 v6.19**, digital audio v6.19, SPI v7.0. Thermal, CPU
DVFS and analogue audio still WIP. USB3, combo-PHY and PCIe all need
out-of-tree drivers. Mainline U-Boot has `radxa-cubie-a5e_defconfig` since
v2025.10-rc1. linux-sunxi summarises the board as *"Supported for basic
headless use cases in mainline Linux and U-Boot."*

Note that `iuncuim`, who publishes the prebuilt A5E OpenWrt images, is **the
same author as the A523 thermal patches this repo already vendors** — a useful
contact if you get stuck.
