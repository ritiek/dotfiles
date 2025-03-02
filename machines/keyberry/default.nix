{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./../zerostash/default.nix
  ];

  networking.hostName = lib.mkForce "keyberry";
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
}
