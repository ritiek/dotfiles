{ config, pkgs, lib, inputs, ... }:

let
  repository = "${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA";
in
{
  sops.secrets."restic.htpasswd".owner = "restic";
  sops.secrets."restic.homelab.password".owner = "restic";

  # The following don't seem to be needed for auto-mount when the
  # "x-systemd.automount" filesystem mount option is set.
  # services.devmon.enable = true;
  # services.gvfs.enable = true; 
  # services.udisks2.enable = true;

  services.restic.server = {
    enable = true;
    listenAddress = "0.0.0.0:52525";
    dataDir = repository;
    # privateRepos = true;
    appendOnly = true;
    extraFlags = [
      "--htpasswd-file=${config.sops.secrets."restic.htpasswd".path}"
    ];
    prometheus = true;
  };

  systemd.services.restic-rest-server.environment = {
    GOMAXPROCS = "1";
    GOGC = "20";
  };

  systemd.services."restic-forget-HOMELAB_MEDIA" = {
    description = "Restic forget+prune and check for HOMELAB_MEDIA (server-side)";
    path = with pkgs; [ restic util-linux ];
    environment.RESTIC_REPOSITORY = repository;
    serviceConfig = {
      Type = "oneshot";
      User = "restic";
      Group = "restic";
      ExecStart = [
        "${pkgs.restic}/bin/restic forget --prune --keep-within-hourly 18h --keep-within-daily 7d --keep-within-weekly 1m --keep-within-monthly 1y --keep-within-yearly 75y --keep-tag forever"
        "${pkgs.restic}/bin/restic check"
      ];
      Environment = "RESTIC_PASSWORD_FILE=${config.sops.secrets."restic.homelab.password".path}";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    unitConfig.RequiresMountsFor = [
      repository
    ];
  };

  systemd.timers."restic-forget-HOMELAB_MEDIA" = {
    description = "Weekly restic forget+prune for HOMELAB_MEDIA (server-side)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon *-*-* 01:00:00";
      Persistent = true;
    };
  };

  fileSystems.restic-backup = {
    mountPoint = "/media/${config.fileSystems.restic-backup.label}";
    device = "/dev/disk/by-label/${config.fileSystems.restic-backup.label}";
    fsType = "ext4";
    label = "RESTIC_BACKUP";
    autoResize = true;
    options = [
      "noatime"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=5s"
    ];
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.fileSystems.restic-backup.label}", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl restart restic-rest-server.service restic-rest-server.socket"
    ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.fileSystems.restic-backup.label}", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl stop restic-rest-server.service restic-rest-server.socket"
  '';
}
