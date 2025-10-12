{ inputs, lib, pkgs, ... }:

{
  imports = [
    ./../zerostash/hw-config.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    # Using this flake input, for some reason haves the kernel compile from source
    # which takes a loong time and isn't practical.
    # inputs.raspberry-pi-nix.nixosModules.raspberry-pi { raspberry-pi-nix.board = "bcm2711"; }
    inputs.pi400kb-nix.nixosModules.pi400kb
  ];

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_rpi4;
  boot.kernelModules = [
    "libcomposite"
    "cma=2048M"
    "i2c-dev"
    "spi-dev"
  ];

  hardware = {
    raspberry-pi."4" = {
      dwc2.enable = true;
      fkms-3d = {
        enable = true;
        cma = 2048;
      };
    };
    graphics.enable = true;
  };
}
