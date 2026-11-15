{ config, lib, pkgs, ... }:
{
  # Key every client sends (OpenCode as x-ocfree-key, hermes as its bearer token).
  sops.secrets."ocfree.key".restartUnits = [ "ocfree.service" ];

  # OpenCode free-tier middleman (./ocfree.ts). Reached over Tailscale only: the port
  # stays out of networking.firewall, and Tailscale's ts-input chain accepts tailscale0.
  systemd.services.ocfree = {
    description = "OpenCode free-tier middleman (egress rotation, hermes shim)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Never give up restarting: every client's free models depend on it.
    startLimitIntervalSec = 0;
    environment = {
      PORT = "9997";
      # 3proxy nodes tried after this host's own IPs, in this order; each over IPv6, then IPv4.
      OCFREE_PROXIES = lib.concatMapStringsSep "," (h: "${h}.lion-zebra.ts.net:8090")
        [ "keyberry" "pilab" "mishy" "nixstation" "zerokvm" ];
    };
    serviceConfig = {
      LoadCredential = [
        "key:${config.sops.secrets."ocfree.key".path}"
        "3proxy:${config.sops.secrets."3proxy.users".path}"
      ];
      ExecStart = "${pkgs.bun}/bin/bun run ${./.}/ocfree.ts";
      Restart = "always";
      RestartSec = 1;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
