{ config, lib, pkgs, ... }:
{
  # Key every client sends as its bearer token (or as x-ocfree-key).
  sops.secrets."ocfree.key".restartUnits = [ "ocfree.service" ];

  # Public gate for models.clawsiecats.omg.lol: a request without the key is dropped
  # (444: connection closed, nothing sent back) before it reaches ocfree, which then
  # checks the key again. Only /.well-known/opencode skips it (see the vhost). The key
  # stays out of the nix store via the sops template. nginx `if` has no `or`, hence the flag.
  sops.templates."nginx-ocfree-gate" = {
    owner = "nginx";
    restartUnits = [ "nginx.service" ];
    content = ''
      set $ocfree_authorized 0;
      if ($http_authorization = "Bearer ${config.sops.placeholder."ocfree.key"}") {
        set $ocfree_authorized 1;
      }
      if ($http_x_ocfree_key = "${config.sops.placeholder."ocfree.key"}") {
        set $ocfree_authorized 1;
      }
      if ($ocfree_authorized = 0) {
        return 444;
      }
    '';
  };

  # OpenCode free-tier middleman (./ocfree.ts). Public through nginx at models.<domain>
  # (behind the gate above); port 9997 itself stays out of networking.firewall, so only
  # the tailnet reaches it directly (Tailscale's ts-input chain accepts tailscale0).
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
        [ "keyberry" "pilab" "mishy" "nixstation" "zerokvm" "m2" "redmi-note-11" ];
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
