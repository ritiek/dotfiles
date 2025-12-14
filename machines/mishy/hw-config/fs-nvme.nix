{ lib, pkgs, ... }:

{
  boot.supportedFilesystems = [ "ntfs" "nfs" ];

  fileSystems."/var/lib/jellyfin" = {
    device = "pilab.lion-zebra.ts.net:/export/jellyfin/config";
    fsType = "nfs";
    options = [ "noatime" "x-systemd.automount" "noauto" "nfsvers=3" ];
  };
  fileSystems."/var/data/jellyfin/movies" = {
    device = "pilab.lion-zebra.ts.net:/export/jellyfin/data/movies";
    fsType = "nfs";
    options = [ "noatime" "x-systemd.automount" "noauto" "nfsvers=3" ];
  };
  fileSystems."/var/data/jellyfin/tvshows" = {
    device = "pilab.lion-zebra.ts.net:/export/jellyfin/data/tvshows";
    fsType = "nfs";
    options = [ "noatime" "x-systemd.automount" "noauto" "nfsvers=3" ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/69b73231-f1da-4668-9c5a-06bf9592fd80";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/225C-7008";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/1aa6d5d2-4d16-4612-ae16-383572e149f1";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress-force=zstd:3"
    ];
  };

  swapDevices = [ ];
}
