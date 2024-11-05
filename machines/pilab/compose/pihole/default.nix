# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, ... }:

{
  sops.secrets."env.pihole" = {
    sopsFile = ./stack.env;
    format = "dotenv";
  };

  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."pihole" = {
    image = "pihole/pihole:latest";
    environment = {
      "TZ" = "Asia/Kolkata";
      "WEB_PORT" = "81";
    };
    environmentFiles = [
      config.sops.secrets."env.pihole".path
    ];
    volumes = [
      "/media/services/pihole:/etc/pihole:rw"
      "pihole_dnsmasq.d:/etc/dnsmasq.d:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--network=host"
    ];
  };
  systemd.services."docker-pihole" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-volume-pihole_dnsmasq.d.service"
    ];
    requires = [
      "docker-volume-pihole_dnsmasq.d.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/services/pihole"
    ];
  };

  # Volumes
  systemd.services."docker-volume-pihole_dnsmasq.d" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker volume rm -f pihole_dnsmasq.d";
    };
    script = ''
      docker volume inspect pihole_dnsmasq.d || docker volume create pihole_dnsmasq.d
    '';
    partOf = [ "docker-compose-pihole-root.target" ];
    wantedBy = [ "docker-compose-pihole-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-pihole-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}