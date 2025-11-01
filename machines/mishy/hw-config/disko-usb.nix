{ lib, ... }:

{
  boot.initrd.luks.devices."cryptroot" = {
    allowDiscards = true;
  };

  disko.devices = {
    disk.main = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0022" "dmask=0022" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true;
              passwordFile = "/tmp/disk.key";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-Lcryptroot" ];
                subvolumes = {
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "noatime" "compress-force=zstd:3" ];
                  };
                };
              };
            };
          };
        };
      };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "size=2G" "mode=755" ];
    };
  };
}