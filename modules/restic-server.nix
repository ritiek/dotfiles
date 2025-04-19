{ config, pkgs, lib, inputs, ... }:

{
  sops.secrets."restic.htpasswd".owner = "restic";

  # The following don't seem to be needed for auto-mount when the
  # "x-systemd.automount" filesystem mount option is set.
  # services.devmon.enable = true;
  # services.gvfs.enable = true; 
  # services.udisks2.enable = true;

  services.restic.server = {
    enable = true;
    listenAddress = "0.0.0.0:52525";
    dataDir = "${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA";
    # privateRepos = true;
    extraFlags = [
      "--htpasswd-file=${config.sops.secrets."restic.htpasswd".path}"
    ];
    prometheus = true;
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
