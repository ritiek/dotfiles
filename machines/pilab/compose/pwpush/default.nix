# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 5100;
  internalWebUIPort = 15100;

  # Import shared lazy-loading utilities
  lazyLoadingLib = import ../lib/lazy-loading.nix { inherit pkgs lib; };

  # Generate lazy-loading services for Password Pusher
  lazyLoadingServices = lazyLoadingLib.mkLazyLoadingServices {
    serviceName = "Password Pusher";
    dockerServiceName = "pwpush";
    webUIPort = webUIPort;
    internalPort = internalWebUIPort;
    refreshInterval = 3;
    requiredMounts = [
      "/media/HOMELAB_MEDIA/services/pwpush"
    ];
    rootTarget = "docker-compose-pwpush-root.target";
    idleCheckInterval = "*:0/10";  # Every 10 minutes (Password Pusher has multiple services)
    # Custom commands for multi-service stack
    startCommand = "systemctl start docker-pwpush-db.service docker-pwpush-worker.service docker-pwpush.service";
    stopCommand = "systemctl stop docker-compose-pwpush-root.target";
    waitTimeout = 60;  # Password Pusher takes longer to start with database
  };

in lib.mkMerge [
  lazyLoadingServices
  {
  sops.secrets."compose/pwpush.env" = {
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
  virtualisation.oci-containers.containers."pwpush-db" = {
    image = "docker.io/postgres:15";
    environmentFiles = [
      config.sops.secrets."compose/pwpush.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/pwpush/pgdata:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=db"
      "--network=pwpush_default"
    ];
  };
  systemd.services."docker-pwpush-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-pwpush_default.service"
    ];
    requires = [
      "docker-network-pwpush_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/pwpush/pgdata"
    ];
    # Bind to root target
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };
  virtualisation.oci-containers.containers."pwpush" = {
    # image = "docker.io/pglombardo/pwpush:latest";
    # Using stable for ARM 64 support for now:
    image = "docker.io/pglombardo/pwpush:stable";
    environmentFiles = [
      config.sops.secrets."compose/pwpush.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/pwpush/settings.yml:/opt/PasswordPusher/config/settings.yml:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:5100/tcp"  # Internal port only
    ];
    dependsOn = [
      "pwpush-db"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=pwpush"
      "--network=pwpush_default"
    ];
  };
  # Restore original docker-pwpush service dependencies
  systemd.services."docker-pwpush" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-pwpush_default.service"
    ];
    requires = [
      "docker-network-pwpush_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/pwpush/settings.yml"
    ];
    # Bind to root target
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };
  virtualisation.oci-containers.containers."pwpush-worker" = {
    image = "docker.io/pglombardo/pwpush-worker:stable";
    environmentFiles = [
      config.sops.secrets."compose/pwpush.env".path
    ];
    dependsOn = [
      "pwpush-db"
      "pwpush"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=worker"
      "--network=pwpush_default"
    ];
  };
  systemd.services."docker-pwpush-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-pwpush_default.service"
    ];
    requires = [
      "docker-network-pwpush_default.service"
    ];
    # Bind to root target
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };

  # Networks
  systemd.services."docker-network-pwpush_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f pwpush_default";
    };
    script = ''
      docker network inspect pwpush_default || docker network create pwpush_default
    '';
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };

  # Root service
  systemd.targets."docker-compose-pwpush-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  }
]
