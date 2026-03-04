{ pkgs, config, ... }:
{
  sops.secrets."netbird.setupkey" = {};

  services.netbird = {
    enable = true;
    ui.enable = true;
    clients.birdnet = {
      login = {
        enable = true;
        setupKeyFile = config.sops.secrets."netbird.setupkey".path;
      };
      port = 51840;
    };
  };
}
