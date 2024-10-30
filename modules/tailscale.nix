{ config, ... }:
{
  sops.secrets."tailscale.authkey" = {};
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets."tailscale.authkey".path;
    useRoutingFeatures = "both";
    extraUpFlags = [
      "--advertise-exit-node"
    ];
  };
}
