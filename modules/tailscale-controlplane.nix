{ config, lib, pkgs, ... }:
{
  sops.secrets."tailscale.authkey" = {};

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets."tailscale.authkey".path;
    useRoutingFeatures = "both";
    extraSetFlags = [ "--operator=ritiek" ];
    extraUpFlags = [
      "--login-server=https://controlplane.clawsiecats.lol"
      "--advertise-exit-node"
      "--reset"
    ];
  };

  systemd.services.tailscaled.serviceConfig = {
    OOMScoreAdjust = -1000;
    Restart = "always";
  };

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };
