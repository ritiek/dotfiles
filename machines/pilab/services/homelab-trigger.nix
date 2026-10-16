{ pkgs, ... }:

let
  # Forced command for Home Assistant on radrubble. The key can only write the
  # OTP trigger file or report whether HOMELAB_MEDIA is mounted.
  sshCommand = pkgs.writeShellScript "homelab-trigger-ssh" ''
    case "$SSH_ORIGINAL_COMMAND" in
      start)
        # Write then rename so the path unit never sees a half-written file.
        head -c 255 > /run/homelab-trigger/.start.tmp
        mv /run/homelab-trigger/.start.tmp /run/homelab-trigger/start
        ;;
      mount-status)
        grep -q ' /media/HOMELAB_MEDIA ' /proc/mounts && echo true || echo false
        ;;
      *)
        echo "unknown command" >&2
        exit 1
        ;;
    esac
  '';
in

{
  users.users.homelab-trigger = {
    isSystemUser = true;
    group = "homelab-trigger";
    # sshd runs the forced command through the login shell.
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      ''restrict,command="${sshCommand}" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjFMSYJiGbMZ2mCmRsMfRuno7ima7EXLSUDZmuhmZt/ hass@radrubble''
    ];
  };
  users.groups.homelab-trigger = { };

  # Trigger directory owned by homelab-trigger so the SSH forced command can
  # write OTP files. A root-level path unit watches this file and runs the
  # actual command.
  systemd.tmpfiles.rules = [
    "d /run/homelab-trigger 0750 homelab-trigger root -"
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
