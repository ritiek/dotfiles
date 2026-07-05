# Hardware/boot-chain wiring for alcove (Radxa Cubie A7S, Allwinner A733 /
# sun60iw2). This is the aarch64-SBC equivalent of what radrubble's
# hw-config.nix does for the Zero 3W (rockchip.uBoot + kernelPackages +
# WiFi driver) - except this board has no dedicated nixos-hardware-style
# helper flake (no mainline A733 support at all, see
# RADXA_CUBIE_A7S_NIXOS_PLAN.md), so everything here is hand-rolled:
# custom kernel (linux-cubie-a7s.nix), vendor U-Boot blobs
# (uboot-cubie-a7s.nix), board DTS/bootloader (cubie-a7s.nix), and the
# out-of-tree USB WiFi driver (aic8800-usb.nix).
{ config, lib, pkgs, modulesPath, ... }:

let
  ubootCubieA7S = pkgs.callPackage ./uboot-cubie-a7s.nix { };
in
{
  imports = [
    ./cubie-a7s.nix
    ./aic8800-usb.nix
    # Gives us `config.system.build.sdImage`, matching what
    # nixos-generators' "sd-aarch64" format does under the hood (it is
    # literally just this one import - see
    # nixos-generators/formats/sd-aarch64.nix). Wiring it in directly here
    # (rather than depending on the nixos-generators flake input like the
    # standalone RADXA_CUBIE_A7S_NIXOS/flake.nix did) lets `alcove-sd` in
    # the top-level flake.nix be defined the same way as `pilab-sd`/
    # `radrubble-sd` - i.e. `self.nixosConfigurations.alcove.config.system.build.sdImage`.
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  # Needed for the unfree vendor boot0/boot_package U-Boot blobs below.
  nixpkgs.config.allowUnfree = true;

  # nixos/modules/system/activation/top-level.nix defaults this option to
  # `config.boot.kernelPackages.kernel.target`, which real nixpkgs kernel
  # derivations get "for free" from buildLinux's own passthru. Our
  # hand-rolled linux-cubie-a7s.nix derivation isn't built via buildLinux
  # (it can't be - Radxa's out-of-tree source tree needs a custom
  # unpack/merge step buildLinux has no hook for), so it has no `.target`
  # attribute and this default fails to evaluate. Set it explicitly to
  # match the filename linux-cubie-a7s.nix's installPhase actually
  # produces (`cp arch/arm64/boot/Image $out/Image`).
  system.boot.loader.kernelFile = "Image";

  # nixos/modules/installer/sd-card/sd-image-aarch64.nix pulls in
  # nixos/modules/profiles/base.nix, which unconditionally forces
  # evaluation of `config.boot.kernelPackages.zfs` (a real, multi-output
  # nixpkgs derivation) to decide `boot.supportedFilesystems.zfs`'s
  # default - our custom single-output linux-cubie-a7s.nix kernel has no
  # `.dev`/`.zfs`-style outputs, so this errors with "attribute 'dev'
  # missing" before boot.zfs.package's own value is ever consulted. We
  # don't need base.nix's bundled btrfs/cifs/f2fs/ntfs/xfs/fuse tooling for
  # this minimal headless image anyway.
  #
  # Separately, nixos/modules/tasks/filesystems/ext.nix unconditionally
  # lists BOTH "ext2" and "ext4" as loadable boot.initrd.availableKernelModules,
  # but our defconfig compiles both CONFIG_EXT2_FS=y and CONFIG_EXT4_FS=y
  # directly into the kernel Image (not as separate .ko files), so the
  # initrd module-closure computation fails looking for module files that
  # will never exist. Neither filesystem needs modprobing here, so disable
  # ext.nix entirely and just pull in the e2fsprogs fsck tools it would
  # have added via fsPackages.
  disabledModules = [ "profiles/base.nix" "tasks/filesystems/ext.nix" ];
  system.fsPackages = [ pkgs.e2fsprogs ];

  # nixos/modules/installer/sd-card/sd-image.nix unconditionally sets
  # `hardware.enableAllHardware = true;`, which gates in
  # nixos/modules/hardware/all-hardware.nix - a huge generic "any x86/any
  # storage controller" module list (3w-9xxx, megaraid_sas, aacraid, etc.)
  # meant for install media on arbitrary hardware. Our minimal defconfig
  # doesn't build any of it, so the initrd modprobe closure check fails.
  # None of this hardware exists on this embedded ARM SBC.
  # NOTE: `boot.initrd.includeDefaultModules = false;` alone (already set
  # in cubie-a7s.nix) is NOT sufficient on its own to fix this - this
  # `mkForce false` is the actual fix.
  hardware.enableAllHardware = lib.mkForce false;

  # nixos/modules/system/boot/systemd/tpm2.nix defaults
  # `boot.initrd.systemd.tpm2.enable` to true (via systemd's own
  # `withTpm2Units`) whenever systemd-in-initrd is enabled, which
  # unconditionally adds "tpm-tis"/"tpm-crb" to
  # boot.initrd.availableKernelModules. This board has no TPM chip and our
  # minimal defconfig doesn't build any TPM drivers, so the initrd
  # module-closure builder fails with "modprobe: FATAL: Module tpm-crb not
  # found". Disable it - there's no TPM to support here anyway.
  boot.initrd.systemd.tpm2.enable = false;

  # Flashable SD card image. boot0/boot_package are raw Allwinner
  # BROM-read blobs written before the partition table gap, NOT part of
  # any partition - dd'd on at fixed byte offsets exposed via
  # uboot-cubie-a7s.nix's passthru. firmwarePartitionOffset is bumped from
  # the 8MiB default to 20MiB so boot_package (ends at ~13.4MiB) can never
  # collide with the (unused on this board) FIRMWARE partition nixpkgs'
  # sd-image module always creates.
  sdImage.compressImage = false;
  sdImage.firmwarePartitionOffset = 20; # MiB
  sdImage.postBuildCommands = ''
    dd if=${ubootCubieA7S}/boot0_sdcard.fex of=$img \
      bs=1024 seek=${toString (ubootCubieA7S.boot0Offset / 1024)} conv=notrunc
    dd if=${ubootCubieA7S}/boot_package.fex of=$img \
      bs=1M seek=${toString (ubootCubieA7S.bootPackageOffset / 1024 / 1024)} conv=notrunc
  '';
}
