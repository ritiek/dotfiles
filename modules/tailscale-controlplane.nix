{ config, pkgs, ... }:
{
  sops.secrets."tailscale.authkey" = {};

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets."tailscale.authkey".path;
    useRoutingFeatures = "both";
    extraUpFlags = [
      "--login-server=https://controlplane.clawsiecats.omg.lol"
      "--advertise-exit-node"
    ];
  };
}
