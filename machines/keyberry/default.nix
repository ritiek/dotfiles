{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./../zerostash/default.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    # Using this flake input, for some reason haves the kernel compile from source
    # which takes a loong time and isn't practical.
    # inputs.raspberry-pi-nix.nixosModules.raspberry-pi { raspberry-pi-nix.board = "bcm2711"; }
    inputs.pi400kb-nix.nixosModules.pi400kb
  ];

  networking.hostName = "keyberry";
  zramSwap.memoryPercent = 200;

  services.uptime-kuma = {
    enable = true;
    appriseSupport = false;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
      # FIXME: This results in a permission error during nixos-rebuild.
      # DATA_DIR = lib.mkForce "/root/uptime-kuma";
    };
  };
  services.pi400kb.enable = true;

  boot.kernelModules = [ "libcomposite" ];
  hardware.raspberry-pi."4".dwc2.enable = true;
}
