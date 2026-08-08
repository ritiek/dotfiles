
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
    default = "mainline-1gb";
    description = ''
      U-Boot variant to embed on this disk image, written at the fixed
      byte offsets the Allwinner BROM reads (see the sdImage comment
      below for the probe order):

      'mainline-1gb' (default) - mainline U-Boot + WIP TF-A, with SPI NOR,
      PCIe/NVMe and USB boot support. Universal: an SD card written with
      this image boots on its own, and on USB/NVMe media - which the BROM
      cannot read at all - the embedded blob is simply never read and boot
      comes from SPI NOR, which holds this same U-Boot build. This board is
      the 1GB LPDDR4 variant; the 2GB/4GB models need incompatible DRAM
      timings (see uboot.nix's mainline-2gb).

      'none' - no U-Boot on disk, reclaiming the 16MiB front gap. Only
      usable on media the BROM cannot read anyway (USB/NVMe), and only
      once mainline U-Boot has been flashed to /dev/mtd0.

      'vendor' - Radxa/Allwinner 2018.07. SD-card boot only, no USB/NVMe
      or SPI NOR support, so it is superseded by 'mainline-1gb' for every
      use case; kept only as a fallback should mainline ever regress.
    '';
  };

  config = {
    # Allwinner U-Boot with extlinux
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.generic-extlinux-compatible.configurationLimit = 4;

    sdImage = {
      compressImage = false;

      # nixpkgs' sd-image-aarch64.nix populates /boot with
      #   extlinux-conf-builder.sh -g <configurationLimit> -c <toplevel> -d ...
      # and that script's -g handling scrapes the *build host's*
      # /nix/var/nix/profiles for `system-*-link` generations to add as extra
      # menu entries, copying each one's kernel and initrd into the image.
      # Since these aarch64 images are built natively on another machine
      # (alcove), that bakes the builder's own generations into the image:
      # menu entries whose `init=` store paths don't exist on this rootfs,
      # booting a kernel for a different SoC entirely, plus tens of MiB of
      # dead weight under /boot/nixos. Pass -g 0 so only the default entry is
      # emitted - getopts honours the last occurrence, overriding the -g
      # already baked into populateCmd. This only affects the image; on the
      # running system the profile genuinely is this machine's, so deploys
      # still get rollback entries (see configurationLimit above).
      populateRootCommands = lib.mkForce ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
          -c ${config.system.build.toplevel} -d ./files/boot -g 0
      '';

      # boot0/boot_package (vendor) or u-boot-sunxi-with-spl.bin (mainline)
      # are raw Allwinner BROM-read blobs written at a fixed byte offset,
      # NOT part of any partition. Bump firmwarePartitionOffset from the
      # 8MiB default to 16MiB so it can never collide with them (matches
      # the original disko-based layout's boot partition start of sector
      # 32768 = 16MiB) - except for uboot="none" (SPI NOR boot), where
      # there's no on-disk U-Boot gap to protect, so keep nixpkgs' default.
      #
      # The BROM probes MMC (at 8KiB and 128KiB), then SPI NOR (at 0), then
      # falls back to USB FEL. It has no USB or NVMe driver whatsoever, so
      # the embedded blob is precisely what makes an SD card self-bootable,
      # while on USB/NVMe media nothing at these offsets is ever read and
      # booting depends entirely on SPI NOR. Confirmed on this board: with a
      # U-Boot-bearing SD inserted the BROM used it even though SPI NOR held
      # a valid mainline U-Boot, and only with the SD removed did it print
      # "Trying to boot from sunxi SPI". MMC therefore always wins, which
      # makes a U-Boot-bearing SD card both the bootstrap path for a board
      # whose SPI NOR is still blank and brick recovery for one whose SPI
      # NOR is corrupt - without having to erase SPI first. (The other
      # recovery route is FEL over USB-C; see the sunxi-fel package output
      # in flake.nix.)
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
