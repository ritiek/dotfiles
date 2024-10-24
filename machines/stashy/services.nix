{ config, pkgs, lib, inputs, ... }:

{
  services = {
    uptime-kuma = {
      enable = true;
      appriseSupport = false;
      settings = {
        DATA_DIR = "/root/uptime-kuma";
      };
    };
  };
}
