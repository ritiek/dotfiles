{ config, pkgs, lib, ... }:
{
  sops.secrets."atticd.env" = {};

  environment.systemPackages = with pkgs; [
    attic-client
  ];

  services.atticd = {
    enable = true;
    environmentFile = config.sops.secrets."atticd.env".path;
    settings = {
      listen = "[::]:7080";
      compression = {
        type = "zstd";
        level = 9;
      };
      database = {
        url = "sqlite://${config.fileSystems.nix-binary-cache.mountPoint}/server.db?mode=rwc";
      };
      storage = {
        type = "local";
        path = config.fileSystems.nix-binary-cache.mountPoint;
      };
    };
  };

  # Disable PrivateUsers to allow access to root-owned mount point
  # while maintaining other security hardening features.
  systemd.services.atticd.serviceConfig.PrivateUsers = lib.mkForce false;

  fileSystems.nix-binary-cache = {
    mountPoint = "/media/${config.fileSystems.nix-binary-cache.label}";
    device = "/dev/disk/by-label/${config.fileSystems.nix-binary-cache.label}";
    fsType = "ext4";
    label = "NIX_BINARY_CACHE";
    autoResize = true;
    options = [
      "noatime"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=5s"
    ];
  };


  # Set world-writable permissions for the mount point
  # Required because DynamicUser creates the atticd group at runtime,
  # so we can't use group-based permissions in tmpfiles rules.
  systemd.tmpfiles.rules = [
    "d ${config.fileSystems.nix-binary-cache.mountPoint} 0777 root root - -"
  ];

  services.udev.extraRules = ''
    # Restart atticd whenever storage is inserted to let atticd re-lookup database.
    # Allows for hot-swapping between multiple Nix binary cache storage drives.
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.fileSystems.nix-binary-cache.label}", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl restart atticd.service"

    # Stop atticd when storage is removed to free up system resources.
    ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.fileSystems.nix-binary-cache.label}", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl stop atticd.service"
  '';
}
