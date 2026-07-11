{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  # Hardware support for the Radxa Cubie A5E (aic8800 wifi/bt driver, board
  # workarounds, disko disk layout) is vendored locally in this directory
  # rather than pulled in as a flake input.
  # Source: https://github.com/patryk4815/nixos-cubie-a5e
  imports = [
    inputs.disko.nixosModules.default
    ./aic8800-sdio.nix
    ./cubie-a5e.nix
    ./disko.nix
  ];

  hardware.cubie-a5e.enable = true;

  # Pinned to match the nixos-cubie-a5e repo's own kernel version (the aic8800
  # SDIO wifi/bt driver requires kernel >= 7.0 - see ./aic8800-sdio.nix).
  boot.kernelPackages = pkgs.linuxPackages_7_0;

  # A523/A527 CPU/GPU/DRAM thermal sensor support (THS0/THS1 controllers).
  # Mainline as shipped in this kernel has no compatible-string match for
  # this SoC's thermal hardware (only the older sun8i/sun50i variants), so
  # /sys/class/thermal reports a static/uninitialized value that never
  # updates. Backported from an upstream series not yet merged as of
  # 2026-07-11: https://patchew.org/linux/20260704171411.1413349-1-iuncuim@gmail.com/
  # "[PATCH v5 0/5] Allwinner: A523: add support for A523 THS0/1 controllers"
  # Once this lands in mainline and nixpkgs bumps the kernel, this
  # kernelPatches list can be dropped.
  boot.kernelPatches = [
    {
      name = "sun55i-a523-thermal-1-dt-bindings";
      patch = ./patches/0001-dt-bindings-thermal-sun8i-add-a523-ths.patch;
    }
    {
      name = "sun55i-a523-thermal-2-reset-control-shared";
      patch = ./patches/0002-thermal-sun8i-reset-control-shared-deasserted.patch;
    }
    {
      name = "sun55i-a523-thermal-3-two-nvmem-cells";
      patch = ./patches/0003-thermal-sun8i-calibration-two-nvmem-cells.patch;
    }
    {
      name = "sun55i-a523-thermal-4-ths0-ths1-driver";
      patch = ./patches/0004-thermal-sun8i-add-a523-ths0-ths1-support.patch;
    }
    {
      name = "sun55i-a523-thermal-5-dts-sensors-zones";
      patch = ./patches/0005-arm64-dts-allwinner-sun55i-add-thermal-sensors.patch;
    }
  ];

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelModules = [ "g_ether" ];

  # USB gadget ethernet - allows SSH over USB-C on first boot
  # Connect to 10.0.0.4 from host (configure host side as 10.0.0.1/24)
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.4";
    prefixLength = 24;
  }];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # disko.imageBuilder.kernelPackages defaults to config.boot.kernelPackages
  # - our aic8800-patched, cross-compiled kernel. Booting the ephemeral
  # image-builder VM with that custom kernel fails with:
  #   "vmTools: the `kernel` argument (kernel-modules) has no `target`
  #   attribute" (pkgs.aggregateModules can't determine a bootable image
  #   filename from it). This is exactly the scenario disko's own option
  #   docs call out ("useful when the config's kernel won't boot in the
  #   image-builder"): use a plain, unmodified kernel from the same shared
  #   nixpkgs just for the image-builder VM. The actual installed target
  #   kernel (linuxPackages_7_0 above) is unaffected.
  disko.imageBuilder.kernelPackages = pkgs.linuxPackages_latest;
}
