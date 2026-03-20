{ pkgs, config, ... }:
{
  sops.secrets."netbird.setupkey" = {
    owner = config.services.netbird.clients.birdnet.user.name;
    group = config.services.netbird.clients.birdnet.user.group;
  };

  # systemd.tmpfiles.rules = [
  #   "d /var/lib/netbird-birdnet/.config 0700 ${config.services.netbird.clients.birdnet.user.name} ${config.services.netbird.clients.birdnet.user.group} -"
  # ];

  services.netbird = {
    enable = true;
    ui.enable = config.hardware.graphics.enable;
    clients.birdnet = {
      # user = {
      #   name = "root";
      #   group = "root";
      # };
      login = {
        enable = true;
        setupKeyFile = config.sops.secrets."netbird.setupkey".path;
        systemdDependencies = [ "run-secrets.d.mount" ];
      };
      openFirewall = true;
      openInternalFirewall = true;
      port = 51840;
    };
  };
}
