
# Vendored from https://github.com/patryk4815/nixos-cubie-a5e
# (modules/disko.nix)
{
  lib,
  config,
  pkgs,
  ...
}:
let
  armTrustedFirmwareSun55i = pkgs.buildPackages.buildArmTrustedFirmware rec {
    platform = "sun55i_a523";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31.bin" ];
    src = pkgs.fetchFromGitHub {
      owner = "jernejsk";
      repo = "arm-trusted-firmware";
      rev = "b5de74a685fb73b784e45bbbd18dd9a0c528d8b2";
      hash = "sha256-6vD3p/mvKpTusGkehowgrKgdTrp8hzesVsoobTUMS40=";
    };
  };

  ubootCubieA5E = pkgs.buildPackages.buildUBoot {
    defconfig = "radxa-cubie-a5e_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    env.BL31 = "${armTrustedFirmwareSun55i}/bl31.bin";
    filesToInstall = [ "u-boot-sunxi-with-spl.bin" ];
  };

  ubootFirmware = pkgs.buildPackages.stdenv.mkDerivation {
    pname = "u-boot-radxa-cubie-a5e";
    version = "2018.07-17";
    src = pkgs.fetchurl {
      url = "https://github.com/radxa-pkg/u-boot-aw2501/releases/download/2018.07-17/u-boot-aw2501_2018.07-17_all.deb";
      hash = "sha256-hM2IV20KDh8TR8v0cyUe4f1RFk5E8sOh+OV/v0pyuok=";
    };
    nativeBuildInputs = [ pkgs.buildPackages.dpkg ];
    unpackPhase = "dpkg-deb -x $src .";
    installPhase = ''
      mkdir -p $out
      cp usr/lib/u-boot/radxa-cubie-a5e/boot0_sdcard.bin $out/
      cp usr/lib/u-boot/radxa-cubie-a5e/boot_package.fex $out/
    '';
  };
in
{
  options.hardware.cubie-a5e = {
    uboot = lib.mkOption {
      type = lib.types.enum [ "vendor" "mainline" ];
      default = "vendor";
      description = "U-Boot variant: 'vendor' (Radxa/Allwinner) or 'mainline' (requires WIP TF-A)";
    };
  };

  options.nixCommunity.disko.device = lib.mkOption {
    type = lib.types.str;
    default = "/dev/mmcblk0";
    description = "Disk device for disko partitioning";
  };

  config = {
    # Allwinner U-Boot with extlinux
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.generic-extlinux-compatible.configurationLimit = 4;

    # Write U-Boot to raw disk after image build
    disko.imageBuilder.extraPostVM = lib.mkMerge [
      (lib.mkIf (config.hardware.cubie-a5e.uboot == "vendor") ''
        dd if=${ubootFirmware}/boot0_sdcard.bin of="$out"/main.raw bs=512 seek=256 conv=notrunc
        dd if=${ubootFirmware}/boot_package.fex of="$out"/main.raw bs=512 seek=24576 conv=notrunc
      '')
      (lib.mkIf (config.hardware.cubie-a5e.uboot == "mainline") ''
        dd if=${ubootCubieA5E}/u-boot-sunxi-with-spl.bin of="$out"/main.raw bs=1k seek=128 conv=notrunc
      '')
    ];

    disko.devices = {
      disk.main = {
        device = config.nixCommunity.disko.device;
        type = "disk";
        imageSize = "6G";
        content = {
          type = "gpt";
          partitions = {
            # First partition starts at sector 32768 (16MB) to not overlap with U-Boot
            boot = {
              size = "2G";
              type = "8300";
              start = "32768";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "root_vg";
              };
            };
          };
        };
      };
      lvm_vg = {
        root_vg = {
          type = "lvm_vg";
          lvs = {
            root = {
              size = "100%FREE";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];

                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                  };

                  "/nix" = {
                    mountOptions = [
                      "subvol=nix"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                };

# files for sops-nix:
#                postMountHook = builtins.toString (
#                  pkgs.writeScript "postMountHook.sh" ''
#                    mkdir -p /mnt/etc/ssh/
#
#                    cp /tmp/ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key
#                    cp /tmp/ssh_host_ed25519_key.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub
#                    cp /tmp/ssh_host_rsa_key /mnt/etc/ssh/ssh_host_rsa_key
#                    cp /tmp/ssh_host_rsa_key.pub /mnt/etc/ssh/ssh_host_rsa_key.pub
#                  ''
#                );
              };
            };
          };
        };
      };
    };
  };
}
