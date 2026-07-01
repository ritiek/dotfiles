{ config, lib, pkgs, modulesPath, inputs, ... }:

let
  noZFS = {
    inputs.nixpkgs.overlays = [
      (final: super: {
        zfs = super.zfs.overrideAttrs (_: { meta.platforms = [ ]; });
      })
    ];
  };

  # Radxa Zero 3E shares the same RK3566 SoC and U-Boot defconfig
  # (radxa-zero-3-rk3566_defconfig) as the Zero 3W, but nixpkgs only ships
  # `ubootRadxaZero3W`, whose defconfig statically defaults `fdtfile` to the
  # 3W's device tree. Without overriding it, U-Boot boots the kernel with the
  # wrong DT (no Ethernet PHY / wrong pinmux for the 3E), which crashes the
  # board into a MaskROM boot loop. Override CONFIG_DEFAULT_FDT_FILE to point
  # at the 3E's DTB instead - confirmed working on real hardware.
  ubootRadxaZero3E = pkgs.ubootRadxaZero3W.overrideAttrs (old: {
    extraConfig = (old.extraConfig or "") + ''
      CONFIG_DEFAULT_FDT_FILE="rockchip/rk3566-radxa-zero-3e.dtb"
    '';
  });
in
{
  imports = [
    inputs.rockchip.nixosModules.sdImageRockchip
    inputs.rockchip.nixosModules.noZFS
  ];

  rockchip.uBoot = ubootRadxaZero3E;

  # Zero 3E has no WiFi (it has Gigabit Ethernet instead of the 3W's aic8800
  # WiFi chip), so unlike radrubble (Zero 3W, pinned to linuxPackages_6_12
  # because the aic8800 driver doesn't build on kernel 7.x+), chocomelt has
  # no reason to stay pinned and can track the latest nixpkgs kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # No WiFi hardware - use DHCP over the onboard Gigabit Ethernet.
  networking.useDHCP = lib.mkDefault true;
}
