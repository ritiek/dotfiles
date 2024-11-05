# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, ... }:

{
  sops.secrets."env.paperless-ngx" = {
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
  virtualisation.oci-containers.containers."paperless-ngx-broker" = {
    image = "docker.io/library/redis:7";
    environmentFiles = [
      config.sops.secrets."env.paperless-ngx".path
    ];
    volumes = [
      "paperless-ngx_redisdata:/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=broker"
      "--network=paperless-ngx_default"
    ];
  };
  systemd.services."docker-paperless-ngx-broker" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-paperless-ngx_default.service"
      "docker-volume-paperless-ngx_redisdata.service"
    ];
    requires = [
      "docker-network-paperless-ngx_default.service"
      "docker-volume-paperless-ngx_redisdata.service"
    ];
  };
  virtualisation.oci-containers.containers."paperless-ngx-db" = {
    image = "docker.io/library/postgres:15";
    environmentFiles = [
      config.sops.secrets."env.paperless-ngx".path
    ];
    volumes = [
      "/media/services/paperless/pgdata:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=db"
      "--network=paperless-ngx_default"
    ];
  };
  systemd.services."docker-paperless-ngx-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-paperless-ngx_default.service"
    ];
    requires = [
      "docker-network-paperless-ngx_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/services/paperless/pgdata"
    ];
  };
  virtualisation.oci-containers.containers."paperless-ngx-webserver" = {
    image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
    environmentFiles = [
      config.sops.secrets."env.paperless-ngx".path
    ];
    volumes = [
      "/media/services/paperless/consume:/usr/src/paperless/consume:rw"
      "/media/services/paperless/data:/usr/src/paperless/data:rw"
      "/media/services/paperless/export:/usr/src/paperless/export:rw"
      "/media/services/paperless/media:/usr/src/paperless/media:rw"
    ];
    ports = [
      "8010:8000/tcp"
    ];
    dependsOn = [
      "paperless-ngx-broker"
      "paperless-ngx-db"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--health-cmd=[\"curl\",\"-fs\",\"-S\",\"--max-time\",\"2\",\"http://localhost:8000\"]"
      "--health-interval=30s"
      "--health-retries=5"
      "--health-timeout=10s"
      "--network-alias=webserver"
      "--network=paperless-ngx_default"
    ];
  };
  systemd.services."docker-paperless-ngx-webserver" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-paperless-ngx_default.service"
    ];
    requires = [
      "docker-network-paperless-ngx_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/services/paperless/consume"
      "/media/services/paperless/data"
      "/media/services/paperless/export"
      "/media/services/paperless/media"
    ];
  };

  # Networks
  systemd.services."docker-network-paperless-ngx_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f paperless-ngx_default";
    };
    script = ''
      docker network inspect paperless-ngx_default || docker network create paperless-ngx_default
    '';
    partOf = [ "docker-compose-paperless-ngx-root.target" ];
    wantedBy = [ "docker-compose-paperless-ngx-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-paperless-ngx_redisdata" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker volume rm -f paperless-ngx_redisdata";
    };
    script = ''
      docker volume inspect paperless-ngx_redisdata || docker volume create paperless-ngx_redisdata
    '';
    partOf = [ "docker-compose-paperless-ngx-root.target" ];
    wantedBy = [ "docker-compose-paperless-ngx-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-paperless-ngx-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
