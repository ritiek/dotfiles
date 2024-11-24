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
    dataDir = config.fileSystems.restic-backup.mountPoint;
    # privateRepos = true;
    extraFlags = [
      "--htpasswd-file=${config.sops.secrets."restic.htpasswd".path}"
    ];
    prometheus = true;
  };
}
