# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, homelabMediaPath, ... }:

let
  # Configuration
  webUIPort = 8454;
  internalWebUIPort = 18454;

  # Import shared lazy-loading utilities
  lazyLoadingLib = import ../lib/lazy-loading.nix { inherit pkgs lib; };

  # Generate lazy-loading services for TubeArchivist
  lazyLoadingServices = lazyLoadingLib.mkLazyLoadingServices {
    serviceName = "TubeArchivist";
    dockerServiceName = "tubearchivist";
    webUIPort = webUIPort;
    internalPort = internalWebUIPort;
    refreshInterval = 3;
    requiredMounts = [
      "${homelabMediaPath}/services/tubearchivist/cache"
      "${homelabMediaPath}/services/tubearchivist/videos"
      "${homelabMediaPath}/services/tubearchivist/es"
    ];
    rootTarget = "docker-compose-tubearchivist-root.target";
    idleCheckInterval = "*:0/10";  # Every 10 minutes (TubeArchivist is heavier)
    # Custom commands for multi-service stack
    startCommand = "systemctl start docker-archivist-redis.service docker-archivist-es.service docker-tubearchivist.service";
    stopCommand = "systemctl stop docker-compose-tubearchivist-root.target";
    healthEndpoint = "/health";
    waitTimeout = 60;  # TubeArchivist takes longer to start
  };

in lib.mkMerge [
  lazyLoadingServices
  {
  sops.secrets."compose/tubearchivist.env" = {
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
  virtualisation.oci-containers.containers."archivist-es" = {
    image = "docker.elastic.co/elasticsearch/elasticsearch:8.9.0";
    environmentFiles = [
      config.sops.secrets."compose/tubearchivist.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/tubearchivist/es:/usr/share/elasticsearch/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=archivist-es"
      "--network=tubearchivist_default"
    ];
  };
  systemd.services."docker-archivist-es" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-tubearchivist_default.service"
    ];
    requires = [
      "docker-network-tubearchivist_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/tubearchivist/es"
    ];
    partOf = [ "docker-compose-tubearchivist-root.target" ];
    wantedBy = [ "docker-compose-tubearchivist-root.target" ];
  };

  virtualisation.oci-containers.containers."archivist-redis" = {
    image = "redis";
    environmentFiles = [
      config.sops.secrets."compose/tubearchivist.env".path
    ];
    volumes = [
      "tubearchivist_redis:/data:rw"
    ];
    dependsOn = [
      "archivist-es"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=archivist-redis"
      "--network=tubearchivist_default"
    ];
  };
  systemd.services."docker-archivist-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-tubearchivist_default.service"
      "docker-volume-tubearchivist_redis.service"
    ];
    requires = [
      "docker-network-tubearchivist_default.service"
      "docker-volume-tubearchivist_redis.service"
    ];
    partOf = [ "docker-compose-tubearchivist-root.target" ];
    wantedBy = [ "docker-compose-tubearchivist-root.target" ];
  };

  virtualisation.oci-containers.containers."tubearchivist" = {
    image = "bbilly1/tubearchivist";
    environmentFiles = [
      config.sops.secrets."compose/tubearchivist.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/tubearchivist/cache:/cache:rw"
      "${homelabMediaPath}/services/tubearchivist/videos:/youtube:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:8000/tcp"  # Internal port only
    ];
    dependsOn = [
      "archivist-es"
      "archivist-redis"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--health-cmd=[\"curl\",\"-f\",\"http://localhost:8000/health\"]"
      "--health-interval=2m0s"
      "--health-retries=3"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=tubearchivist"
      "--network=tubearchivist_default"
    ];
  };
  systemd.services."docker-tubearchivist" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-tubearchivist_default.service"
    ];
    requires = [
      "docker-network-tubearchivist_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/tubearchivist/cache"
      "${homelabMediaPath}/services/tubearchivist/videos"
    ];
    partOf = [ "docker-compose-tubearchivist-root.target" ];
    wantedBy = [ "docker-compose-tubearchivist-root.target" ];
  };

  # Networks
  systemd.services."docker-network-tubearchivist_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f tubearchivist_default";
    };
    script = ''
      docker network inspect tubearchivist_default || docker network create tubearchivist_default
    '';
    partOf = [ "docker-compose-tubearchivist-root.target" ];
    wantedBy = [ "docker-compose-tubearchivist-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-tubearchivist_redis" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker volume rm -f tubearchivist_redis";
    };
    script = ''
      docker volume inspect tubearchivist_redis || docker volume create tubearchivist_redis
    '';
    partOf = [ "docker-compose-tubearchivist-root.target" ];
    wantedBy = [ "docker-compose-tubearchivist-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-tubearchivist-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  }
]
