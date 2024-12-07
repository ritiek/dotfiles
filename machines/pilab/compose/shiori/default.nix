# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, ... }:

{
  sops.secrets."compose/shiori.env" = {
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
  virtualisation.oci-containers.containers."shiori" = {
    image = "ghcr.io/go-shiori/shiori:dev";
    environmentFiles = [
      config.sops.secrets."compose/shiori.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/shiori/dev:/srv/shiori:rw"
      "/media/HOMELAB_MEDIA/services/shiori/src:/src/shiori:rw"
    ];
    ports = [
      "2397:8080/tcp"
    ];
    dependsOn = [
      "shiori-postgres"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=shiori"
      "--network=shiori_default"
    ];
  };
  systemd.services."docker-shiori" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-shiori_default.service"
    ];
    requires = [
      "docker-network-shiori_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/shiori/dev"
      "/media/HOMELAB_MEDIA/services/shiori/src"
    ];
  };
  virtualisation.oci-containers.containers."shiori-postgres" = {
    image = "postgres:15";
    environmentFiles = [
      config.sops.secrets."compose/shiori.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/shiori/postgresql:/var/lib/postgresql/data:rw"
    ];
    ports = [
      "5432:5432/tcp"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=postgres"
      "--network=shiori_default"
    ];
  };
  systemd.services."docker-shiori-postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-shiori_default.service"
    ];
    requires = [
      "docker-network-shiori_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/shiori/postgresql"
    ];
  };

  # Networks
  systemd.services."docker-network-shiori_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f shiori_default";
    };
    script = ''
      docker network inspect shiori_default || docker network create shiori_default
    '';
    partOf = [ "docker-compose-shiori-root.target" ];
    wantedBy = [ "docker-compose-shiori-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-shiori-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
