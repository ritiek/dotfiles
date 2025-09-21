# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 9091;
  internalWebUIPort = 19091;

  # Import shared lazy-loading utilities
  lazyLoadingLib = import ../lib/lazy-loading.nix { inherit pkgs lib; };

  # Generate lazy-loading services for Mealie
  lazyLoadingServices = lazyLoadingLib.mkLazyLoadingServices {
    serviceName = "Mealie";
    dockerServiceName = "mealie";
    webUIPort = webUIPort;
    internalPort = internalWebUIPort;
    refreshInterval = 3;
    requiredMounts = [
      "/media/HOMELAB_MEDIA/services/mealie"
    ];
    rootTarget = "docker-compose-mealie-root.target";
    idleCheckInterval = "*:0/10";  # Every 10 minutes (Mealie is heavier with multiple services)
    # Custom commands for multi-service stack
    startCommand = "systemctl start docker-mealie_dev_postgres.service docker-mealie_dev_mailpit.service docker-mealie.service";
    stopCommand = "systemctl stop docker-compose-mealie-root.target";
    waitTimeout = 60;  # Mealie takes longer to start with database
  };

in lib.mkMerge [
  lazyLoadingServices
  {
  sops.secrets."compose/mealie.env" = {
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
  virtualisation.oci-containers.containers."mealie" = {
    image = "hkotel/mealie";
    environmentFiles = [
      config.sops.secrets."compose/mealie.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/mealie/data:/app/data:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:9000/tcp"  # Internal port only
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=mealie"
      "--network=mealie_default"
    ];
  };
  # Restore original docker-mealie service dependencies
  systemd.services."docker-mealie" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-mealie_default.service"
    ];
    requires = [
      "docker-network-mealie_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/mealie/data"
    ];
    # Bind to root target
    partOf = [ "docker-compose-mealie-root.target" ];
    wantedBy = [ "docker-compose-mealie-root.target" ];
  };
  virtualisation.oci-containers.containers."mealie_dev_mailpit" = {
    image = "axllent/mailpit:latest";
    environmentFiles = [
      config.sops.secrets."compose/mealie.env".path
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=mailpit"
      "--network=mealie_default"
    ];
  };
  systemd.services."docker-mealie_dev_mailpit" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-mealie_default.service"
    ];
    requires = [
      "docker-network-mealie_default.service"
    ];
    # Bind to root target
    partOf = [ "docker-compose-mealie-root.target" ];
    wantedBy = [ "docker-compose-mealie-root.target" ];
  };
  virtualisation.oci-containers.containers."mealie_dev_postgres" = {
    image = "postgres:15";
    environmentFiles = [
      config.sops.secrets."compose/mealie.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/mealie/postgresql:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=postgres"
      "--network=mealie_default"
    ];
  };
  systemd.services."docker-mealie_dev_postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-mealie_default.service"
    ];
    requires = [
      "docker-network-mealie_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/mealie/postgresql"
    ];
    # Bind to root target
    partOf = [ "docker-compose-mealie-root.target" ];
    wantedBy = [ "docker-compose-mealie-root.target" ];
  };

  # Networks
  systemd.services."docker-network-mealie_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f mealie_default";
    };
    script = ''
      docker network inspect mealie_default || docker network create mealie_default
    '';
    partOf = [ "docker-compose-mealie-root.target" ];
    wantedBy = [ "docker-compose-mealie-root.target" ];
  };

  # Root service
  systemd.targets."docker-compose-mealie-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  }
]
