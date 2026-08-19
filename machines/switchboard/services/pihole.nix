# Native Pi-hole (pihole-ftl + pihole-web), replacing pilab's dockerized
# pihole/pihole container with nixpkgs' native NixOS modules.
#
# This is an INDEPENDENT/secondary Pi-hole instance -- it does not replace
# pilab as the network's primary DNS resolver. It owns port 53 directly
# (no host dnsmasq layer, unlike pilab which forwards port 53 -> 5335).
#
# Admin password hash, static DNS hosts/CNAMEs, DNS upstreams and adlists
# are reused verbatim from pilab's live pihole.toml/gravity.db per user
# request, to keep behavior consistent between the two instances.
{ config, lib, ... }:
{
  services.pihole-ftl = {
    enable = true;

    openFirewallDNS = true;
    openFirewallWebserver = true;
    # DHCP stays disabled (matches pilab's dhcp.active = false).
    openFirewallDHCP = false;

    # Deliberately EMPTY -- see the pihole-gravity service at the bottom of this
    # file. The blocklists themselves are unchanged and still live in
    # gravity.db; they are simply no longer managed through this option.
    #
    # Currently seeded (verified in gravity.db, both enabled):
    #   https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
    #   https://github.com/Pyenb/Pi-hole-blocklist/raw/refs/heads/main/blocklist.txt
    #
    # Why: `lists` is a one-way first-boot seeder, not a declarative option.
    # It POSTs each URL to the FTL API on every boot, and nixpkgs'
    # pihole-ftl-setup-script.nix treats the resulting
    #   "UNIQUE constraint failed: adlist.address, adlist.type"
    # as a failure, so `pihole-ftl-setup.service` exits 1 on every boot after
    # the first and sits in `systemctl --failed` forever. Gravity itself
    # succeeds; only the exit code is wrong. Removing entries from this list
    # also does not remove them from gravity.db (nixpkgs#505714), so it never
    # actually reconciled state either way.
    #
    # `enable = builtins.length cfg.lists > 0` in the upstream module means
    # emptying this makes the broken unit disappear entirely.
    #
    # To add or remove a blocklist now: use the Pi-hole web UI, and update the
    # comment above so the repo still records what is configured.
    lists = [ ];

    settings = {
      dns = {
        upstreams = [
          "1.0.0.1"
          "2606:4700:4700::1111"
          "1.1.1.1"
          "2606:4700:4700::1001"
        ];
        piholePTR = "HOSTNAMEFQDN";
        bogusPriv = false;
        listeningMode = "ALL";
        # port left at default (53) -- this is an independent instance that
        # owns port 53 directly, unlike pilab's 5335 host-dnsmasq workaround.

        reply.host.force4 = true;

        hosts = [
          "192.168.2.8 pilab-ethernet.pihole"
          "192.168.1.150 proxmox-minipc-ntfy.pihole"
          "192.168.1.200 proxmox-minipc-tailscale.pihole"
          "192.168.1.149 proxmox-minipc.pihole"
          "192.168.1.199 proxmox-minipc-cloudflare.pihole"
          "192.168.1.191 proxmox-minipc-crypto.pihole"
          "192.168.1.196 proxmox-minipc-central-db.pihole"
          "192.168.1.198 proxmox-minipc-nginx.pihole"
          "192.168.1.18 proxmox-miner-hiveos.pihole"
          "192.168.1.151 proxmox-minipc-homeassistant.pihole"
          "192.168.2.14 robotic-arm-esp32.pihole"
          "192.168.2.15 redmi-note-11.pihole"
          "192.168.1.29 keyberry.pihole"
          "192.168.1.6 deco-m5-pratiek-room.pihole"
          "192.168.1.37 tablet-android-pa.pihole"
          "192.168.1.12 main-phase.pihole"
          "192.168.1.11 unknown-device-1.pihole"
          "192.168.1.5 miner-smart-switch.pihole"
          "192.168.1.35 alexa.pihole"
          "192.168.1.34 unknown-device-4.pihole"
          "192.168.1.45 deco-m5-fridge.pihole"
          "192.168.1.9 esp8266-pratiek-room.pihole"
          "192.168.1.17 imou-2.pihole"
          "192.168.1.31 unknown-device-3.pihole"
          "192.168.1.13 esp8266-fan-1.pihole"
          "192.168.1.40 esp8266-fan-2.pihole"
          "192.168.1.50 proxmox-miner-windows.pihole"
          "192.168.1.43 proxmox-miner.pihole"
          "192.168.2.11 pilab-wlan.pihole"
          "192.168.1.54 esp8266-outside-area.pihole"
          "192.168.1.60 google-nest-mini.pihole"
          "192.168.1.25 proxmox-miner-nixos.pihole"
          "192.168.2.5 mumbai-halox-switch.pihole"
          "192.168.2.4 mumbai-zebronics-switch.pihole"
          "192.168.1.36 itek-camera-front-door.pihole"
          "192.168.1.64 amazon-fire-stick-tv.pihole"
          "192.168.1.68 imou-3.pihole"
          "192.168.1.69 raspberry-pi.pihole"
          "192.168.1.74 imou-1.pihole"
          "192.168.2.13 phillips-air-purifier.pihole"
          "192.168.2.14 mishy.pihole"
          "192.168.1.80 imou-4.pihole"
          "192.168.1.82 miner-switch.pihole"
          "192.168.2.9 ritiek-edra-m2.pihole"

          # switchboard's own LAN (192.168.3.0/24). Everything above is still on
          # the ONT's segment; these are the hosts that have moved behind the
          # router. Pinned in modules/router/dhcp.nix -- keep the two in sync.
          "192.168.3.1 switchboard.pihole"
          "192.168.3.2 alcove.pihole"
        ];

        cnameRecords = [
          "mishy,mishy.lion-zebra.ts.net,600"
          "keyberry,keyberry.lion-zebra.ts.net,600"
          "clawsiecats,clawsiecats.lion-zebra.ts.net,600"
          "radrubble,radrubble.lion-zebra.ts.net,600"
        ];
      };

      webserver = {
        headers = [
          "X-DNS-Prefetch-Control: off"
          "Content-Security-Policy: default-src 'self' 'unsafe-inline';"
          "X-Frame-Options: DENY"
          "X-XSS-Protection: 0"
          "X-Content-Type-Options: nosniff"
          "Referrer-Policy: strict-origin-when-cross-origin"
        ];
        session.timeout = 60;
        interface.theme = "default-dark";
        api = {
          max_sessions = 128;
          app_sudo = true;
          # Required for the `pihole` CLI to authenticate against the local
          # API -- `pihole -g` in the pihole-gravity service below needs it.
          cli_pw = true;
          # Reused verbatim from pilab's live pihole.toml (same admin +
          # app password as pilab's instance, per user request).
          pwhash = "$BALLOON-SHA256$v=1$s=1024,t=32$0CXmDtL0AJ2fina5PbN6Dw==$tVAj7+on6sfYMDRyt8UdNAeodrGSj4EO0uYS//lMOD8=";
          app_pwhash = "$BALLOON-SHA256$v=1$s=1024,t=32$0UL4DHRsNhZUFVgbCFwFtA==$AqqGF+GBt/3h38pUFxWnLdjUNurkYryDGN66134aVy4=";
        };
      };
    };
  };

  services.pihole-web = {
    enable = true;
    hostName = "switchboard.lion-zebra.ts.net";
    ports = [ 80 ];
  };

  # Periodic blocklist refresh.
  #
  # nixpkgs' pihole-ftl module ships NO gravity timer at all -- the only thing
  # that ever runs `pihole -g` is pihole-ftl-setup.service, which we disabled
  # above (and which only ran at boot anyway). Without this, blocklists would
  # go stale until the next reboot.
  #
  # Hardening below mirrors upstream's pihole-ftl-setup unit.
  systemd.services.pihole-gravity = {
    description = "Pi-hole gravity (blocklist) refresh";
    after = [
      "network-online.target"
      "pihole-ftl.service"
    ];
    wants = [
      "network-online.target"
      "pihole-ftl.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = config.services.pihole-ftl.user;
      Group = config.services.pihole-ftl.group;

      # Runs as the pihole user, so the CLI's internal sudo wrapper is a no-op.
      ExecStart = "${lib.getExe config.services.pihole-ftl.piholePackage} -g";

      # Gravity pulls several million domains; be a good citizen on a board
      # with no cpufreq driver and therefore no ability to throttle itself.
      Nice = 10;
      IOSchedulingClass = "idle";

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      DevicePolicy = "closed";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ReadWritePaths = [
        config.services.pihole-ftl.configDirectory
        config.services.pihole-ftl.stateDirectory
        config.services.pihole-ftl.logDirectory
      ];
      RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
    };
  };

  systemd.timers.pihole-gravity = {
    description = "Weekly Pi-hole gravity refresh";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      # Deliberately NOT tied to boot: a full gravity rebuild costs ~1.5 min
      # CPU and ~330M RSS, which is not what this board should be doing while
      # the household is waiting for the router to come up.
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
