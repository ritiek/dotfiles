# Auto-generated using compose2nix v0.3.1.
{ config, pkgs, lib, ... }:

{
  sops.secrets = {
    "compose/changedetection.env" = {
      sopsFile = ./stack.env;
      format = "dotenv";
    };
    # "compose/changedetection-api-key.txt" = {
    #   sopsFile = ./stack.env;
    #   format = "dotenv";
    #   key = "HOMEPAGE_DASHBOARD_API_KEY";
    # };
  };

  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."changedetection" = {
    image = "ghcr.io/dgtlmoon/changedetection.io";
    environmentFiles = [
      config.sops.secrets."compose/changedetection.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/changedetection:/datastore:rw"
    ];
    ports = [
      "5000:5000/tcp"
    ];
    dependsOn = [
      "changedetection-sockpuppetbrowser"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--dns=127.0.0.1"
      "--dns=100.100.100.100"
      "--dns=1.1.1.1"
      "--dns=8.8.8.8"
      "--hostname=changedetection"
      "--network-alias=changedetection"
      "--network=changedetection_default"
    ];
    labels = {
      "homepage.description" = "Monitor webpages for changes";
      "homepage.group" = "Monitoring";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:5000";
      "homepage.icon" = "changedetection";
      "homepage.name" = "ChangeDetection";
      # "homepage.widget.type" = "changedetectionio";
      # "homepage.widget.url" = "http://host.docker.internal:5000/";
      # "homepage.widget.key" = config.sops.secrets."compose/changedetection-api-key.txt".path;
    };
  };
  systemd.services."docker-changedetection" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-changedetection_default.service"
    ];
    requires = [
      "docker-network-changedetection_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/changedetection"
    ];
  };
  virtualisation.oci-containers.containers."changedetection-sockpuppetbrowser" = {
    image = "dgtlmoon/sockpuppetbrowser:latest";
    environmentFiles = [
      config.sops.secrets."compose/changedetection.env".path
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--dns=1.1.1.1"
      "--dns=100.100.100.100"
      "--dns=127.0.0.1"
      "--dns=8.8.8.8"
      "--cap-add=SYS_ADMIN"
      "--hostname=sockpuppetbrowser"
      "--network-alias=sockpuppetbrowser"
      "--network=changedetection_default"
    ];
  };
  systemd.services."docker-changedetection-sockpuppetbrowser" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-changedetection_default.service"
    ];
    requires = [
      "docker-network-changedetection_default.service"
    ];
  };

  # Networks
  systemd.services."docker-network-changedetection_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f changedetection_default";
    };
    script = ''
      docker network inspect changedetection_default || docker network create changedetection_default
    '';
    partOf = [ "docker-compose-changedetection-root.target" ];
    wantedBy = [ "docker-compose-changedetection-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-changedetection-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
