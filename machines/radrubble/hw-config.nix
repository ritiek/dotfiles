{ config, lib, pkgs, modulesPath, inputs, ... }:

let
  noZFS = {
    inputs.nixpkgs.overlays = [
      (final: super: {
        zfs = super.zfs.overrideAttrs (_: { meta.platforms = [ ]; });
      })
    ];
  };
in
{
  imports = [
    inputs.rockchip.nixosModules.sdImageRockchip
    inputs.rockchip.nixosModules.noZFS
  ];

  rockchip.uBoot = inputs.rockchip.packages."aarch64-linux".uBootRadxaCM3IO;
  boot.kernelPackages = inputs.rockchip.legacyPackages."aarch64-linux".kernel_linux_6_12_rockchip;
}
