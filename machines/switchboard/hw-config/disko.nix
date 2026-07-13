
# Originally vendored from https://github.com/patryk4815/nixos-cubie-a5e
# (modules/disko.nix), but rewritten to build the SD image via nixpkgs'
# own installer/sd-card/sd-image-aarch64.nix instead of disko.
#
# disko's pinned rev (nix-community/disko) wraps
# `disko.imageBuilder.kernelPackages.kernel` in `pkgs.aggregateModules`
# before handing it to `pkgs.vmTools` as the `kernel` argument. A recent
# nixpkgs change requires `kernel` to be a real kernel derivation with a
# `.target` attribute (extra modules now go through a separate
# `kernelModules` argument instead), so this fails unconditionally
# regardless of which kernelPackages we pick - a disko/nixpkgs version
# mismatch, not something fixable from here. alcove (Cubie A7S, the sibling
# Allwinner board in this repo) already builds its SD image the plain
# nixpkgs way with no VM/vmTools involved at all, so we do the same here:
# keep the same U-Boot/ATF derivations and byte-offset dd writes, just
# swap disko's partitioning/image-building for sd-image-aarch64.nix.
{
  lib,
  config,
  pkgs,
  modulesPath,
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
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  options.hardware.cubie-a5e.uboot = lib.mkOption {
    type = lib.types.enum [ "vendor" "mainline" ];
    default = "vendor";
    description = "U-Boot variant: 'vendor' (Radxa/Allwinner) or 'mainline' (requires WIP TF-A)";
  };

  config = {
    # Allwinner U-Boot with extlinux
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.generic-extlinux-compatible.configurationLimit = 4;

    sdImage = {
      compressImage = false;

      # boot0/boot_package (vendor) or u-boot-sunxi-with-spl.bin (mainline)
      # are raw Allwinner BROM-read blobs written at fixed byte offsets,
      # NOT part of any partition. Bump firmwarePartitionOffset from the
      # 8MiB default to 16MiB so it can never collide with them (matches
      # the original disko-based layout's boot partition start of sector
      # 32768 = 16MiB).
      firmwarePartitionOffset = 16; # MiB

      postBuildCommands = lib.mkMerge [
        (lib.mkIf (config.hardware.cubie-a5e.uboot == "vendor") ''
          dd if=${ubootFirmware}/boot0_sdcard.bin of=$img bs=512 seek=256 conv=notrunc
          dd if=${ubootFirmware}/boot_package.fex of=$img bs=512 seek=24576 conv=notrunc
        '')
        (lib.mkIf (config.hardware.cubie-a5e.uboot == "mainline") ''
          dd if=${ubootCubieA5E}/u-boot-sunxi-with-spl.bin of=$img bs=1k seek=128 conv=notrunc
        '')
      ];
    };

    fileSystems."/" = lib.mkDefault {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };
}
