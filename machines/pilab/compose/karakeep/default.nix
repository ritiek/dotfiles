# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 2398;
  internalWebUIPort = 12398;

  # Import lazy-loading module
  lazyLoadingLib = import ../lib/lazy-loading.nix { inherit pkgs lib; };
  
  # Generate lazy-loading services with custom commands for multi-service stack
  lazyLoadingServices = lazyLoadingLib.mkLazyLoadingServices {
    serviceName = "Karakeep";
    dockerServiceName = "karakeep";
    webUIPort = webUIPort;
    internalPort = internalWebUIPort;
    requiredMounts = [ "/media/HOMELAB_MEDIA/services/karakeep/meilisearch" "/media/HOMELAB_MEDIA/services/karakeep/data" ];
    rootTarget = "docker-compose-karakeep-root.target";
    startCommand = "systemctl start docker-karakeep-chrome.service docker-karakeep-meilisearch.service docker-karakeep.service";
    stopCommand = "systemctl stop docker-compose-karakeep-root.target";
    waitTimeout = 180; # 3 minutes for complex stack
  };

in lib.mkMerge [
  lazyLoadingServices
  {
  sops.secrets."compose/karakeep.env" = {
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
  virtualisation.oci-containers.containers."karakeep-chrome" = {
    image = "gcr.io/zenika-hub/alpine-chrome:123";
    environmentFiles = [
      config.sops.secrets."compose/karakeep.env".path
    ];
    cmd = [ "--no-sandbox" "--disable-gpu" "--disable-dev-shm-usage" "--remote-debugging-address=0.0.0.0" "--remote-debugging-port=9222" "--hide-scrollbars" ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=chrome"
      "--network=karakeep_default"
    ];
  };
  systemd.services."docker-karakeep-chrome" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
    ];
    # Bind to root target
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };
  virtualisation.oci-containers.containers."karakeep-meilisearch" = {
    image = "getmeili/meilisearch:v1.13.3";
    environment = {
      "MEILI_NO_ANALYTICS" = "true";
    };
    environmentFiles = [
      config.sops.secrets."compose/karakeep.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/karakeep/meilisearch:/meili_data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=meilisearch"
      "--network=karakeep_default"
    ];
  };
  systemd.services."docker-karakeep-meilisearch" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/karakeep/meilisearch"
    ];
    # Bind to root target
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };
  virtualisation.oci-containers.containers."karakeep" = {
    image = "ghcr.io/karakeep-app/karakeep:release";
    environment = {
      "BROWSER_WEB_URL" = "http://chrome:9222";
      "DATA_DIR" = "/data";
      "MEILI_ADDR" = "http://meilisearch:7700";
    };
    environmentFiles = [
      config.sops.secrets."compose/karakeep.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/karakeep/data:/data:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:3000/tcp"  # Internal port only
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=web"
      "--network=karakeep_default"
    ];
  };
  systemd.services."docker-karakeep" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
      "docker-karakeep-meilisearch.service"
      "docker-karakeep-chrome.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/karakeep/data"
    ];
    # Bind to root target
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };

  # Networks
  systemd.services."docker-network-karakeep_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f karakeep_default";
    };
    script = ''
      docker network inspect karakeep_default || docker network create karakeep_default
    '';
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-karakeep-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
} ]
