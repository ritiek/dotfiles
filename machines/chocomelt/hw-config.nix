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
    # Rockchip's BL31 (as Armbian uses): the vendor kernel needs its SCMI/SIP
    # services, mainline TF-A hangs it.
    env = old.env // { BL31 = pkgs.rkbin.BL31_RK3568; };
    # btrfs: U-Boot reads kernel/initrd from /boot on the btrfs root.
    extraConfig = (old.extraConfig or "") + ''
      CONFIG_DEFAULT_FDT_FILE="rockchip/rk3566-radxa-zero-3e.dtb"
      CONFIG_FS_BTRFS=y
      CONFIG_CMD_BTRFS=y
    '';
  });
in
{
  imports = [
    inputs.rockchip.nixosModules.sdImageRockchip
    inputs.rockchip.nixosModules.noZFS
    ./../../modules/radxa-zero3
  ];

  # The shared Zero 3 DT enables the 3W's WiFi/BT; the 3E has none. Same as
  # the vendor's radxa-zero3-disabled-wireless.dtbo.
  hardware.deviceTree.overlays = [{
    name = "rk3566-zero3e-no-wireless";
    dtsText = ''
      /dts-v1/;
      /plugin/;
      / { compatible = "rockchip,rk3566"; };
      &uart1 { status = "disabled"; };
      &sdmmc1 { status = "disabled"; };
    '';
  }];

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelModules = [ "g_ether" ];

  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.3";
    prefixLength = 24;
  }];

  rockchip.uBoot = ubootRadxaZero3E;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
