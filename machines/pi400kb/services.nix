{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.pi400kb-nix.nixosModules.pi400kb
  ];
  services.pi400kb.enable = true;

  services = {
    uptime-kuma = {
      enable = true;
      appriseSupport = false;
      settings = {
        HOST = "0.0.0.0";
        PORT = "3001";
        # FIXME: This results in a permission error during nixos-rebuild.
        # DATA_DIR = lib.mkForce "/root/uptime-kuma";
      };
    };
  };
}
