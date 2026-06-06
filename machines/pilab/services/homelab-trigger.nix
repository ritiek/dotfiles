{ pkgs, ... }:

{
  # Create trigger directory owned by hass so HA shell_command can write OTP files.
  # A root-level path unit watches this file and runs the actual command outside
  # HA's restrictive systemd sandbox (which blocks setuid/privilege syscalls).
  systemd.tmpfiles.rules = [
    "d /run/homelab-trigger 0750 hass root -"
  ];

  # --- homelab-start trigger ---

  systemd.paths.homelab-start-trigger = {
    description = "Watch for homelab-start OTP trigger from Home Assistant";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = "/run/homelab-trigger/start";
  };

  systemd.services.homelab-start-trigger = {
    description = "Run homelab-start when triggered by Home Assistant";
    serviceConfig = {
      Type = "oneshot";
      Environment = "PATH=/run/current-system/sw/bin:/run/wrappers/bin:/etc/profiles/per-user/ritiek/bin";
      ExecStart = "${pkgs.writeShellScript "homelab-start-trigger" ''
        OTP=$(cat /run/homelab-trigger/start 2>/dev/null || true)
        rm -f /run/homelab-trigger/start
        exec env HOMELAB_OTP="$OTP" /etc/profiles/per-user/ritiek/bin/homelab-start
      ''}";
    };
  };
}
