{ lib, ... }:

{
  boot.initrd.kernelModules = [ "usb_storage" "uas" "vfat" "nls_cp437" "nls_iso8859-1" "usbhid" ];

  # Enable Yubikey support in initrd
  boot.initrd.luks.yubikeySupport = true;

  boot.initrd.luks.devices."cryptroot" = {
    preLVM = true;
    yubikey = {
      slot = 1;
      twoFactor = false;  # false = Yubikey OR password, true = Yubikey AND password
      gracePeriod = 30;
      keyLength = 64;
      saltLength = 16;
      storage = {
        device = "/dev/disk/by-label/BOOT";
        path = "/crypt-storage/default";
      };
    };
  };

  disko.devices = {
    disk.main = {
      device = lib.mkDefault "/dev/sda_or_some_device";   # This can be overriden through command line params.
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
              extraArgs = [ "-n" "BOOT" ];  # Label for Yubikey storage
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
