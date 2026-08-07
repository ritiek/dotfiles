
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
  uboot = import ./uboot.nix { inherit pkgs; };
in
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  options.hardware.cubie-a5e.uboot = lib.mkOption {
    type = lib.types.enum [ "none" "vendor" "mainline-1gb" ];
    default = "vendor";
    description = ''
      U-Boot variant to embed on this disk image:
      'none' for SPI NOR boot (no U-Boot on the SD/NVMe/USB disk itself -
      used once mainline U-Boot has been flashed to /dev/mtd0),
      'vendor' (Radxa/Allwinner, SD-card boot only), or
      'mainline-1gb' (mainline, WIP TF-A, adds SPI NOR + PCIe/NVMe boot
      support; this board is the 1GB LPDDR4 variant).
    '';
  };

  config = {
    # Allwinner U-Boot with extlinux
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.generic-extlinux-compatible.configurationLimit = 4;

    sdImage = {
      compressImage = false;

      # boot0/boot_package (vendor) or u-boot-sunxi-with-spl.bin (mainline)
      # are raw Allwinner BROM-read blobs written at a fixed byte offset,
      # NOT part of any partition. Bump firmwarePartitionOffset from the
      # 8MiB default to 16MiB so it can never collide with them (matches
      # the original disko-based layout's boot partition start of sector
      # 32768 = 16MiB) - except for uboot="none" (SPI NOR boot), where
      # there's no on-disk U-Boot gap to protect, so keep nixpkgs' default.
      firmwarePartitionOffset = if config.hardware.cubie-a5e.uboot == "none" then 8 else 16; # MiB

      # vendor and mainline-1gb both expose a single pre-combined
      # u-boot-sunxi-with-spl.bin blob (see uboot.nix), so both cases write
      # it at the same fixed offset; uboot="none" writes nothing.
      postBuildCommands = lib.mkIf (config.hardware.cubie-a5e.uboot != "none") ''
        dd if=${
          if config.hardware.cubie-a5e.uboot == "vendor" then uboot.vendor else uboot.mainline-1gb
        }/u-boot-sunxi-with-spl.bin of=$img bs=1k seek=128 conv=notrunc
      '';
    };

    fileSystems."/" = lib.mkDefault {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };
}
