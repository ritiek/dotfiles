# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

{
  sops.secrets."compose/dawarich.env" = {
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
  virtualisation.oci-containers.containers."dawarich" = {
    image = "freikin/dawarich:latest";
    environment = {
      "APPLICATION_HOSTS" = "pilab.lion-zebra.ts.net,localhost";
      "APPLICATION_PROTOCOL" = "http";
      "DATABASE_HOST" = "dawarich_db";
      "DATABASE_NAME" = "dawarich_development";
      "DISABLE_HOST_AUTHORIZATION" = "true";
      "DISTANCE_UNIT" = "km";
      "ENABLE_TELEMETRY" = "false";
      "MIN_MINUTES_SPENT_IN_CITY" = "60";
      "PROMETHEUS_EXPORTER_ENABLED" = "false";
      "PROMETHEUS_EXPORTER_HOST" = "0.0.0.0";
      "PROMETHEUS_EXPORTER_PORT" = "9394";
      "RAILS_ENV" = "development";
      "REDIS_URL" = "redis://dawarich_redis:6379/0";
      "TIME_ZONE" = "Asia/Kolkata";
    };
    environmentFiles = [
      config.sops.secrets."compose/dawarich.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/dawarich/public:/var/app/public:rw"
      "/media/HOMELAB_MEDIA/services/dawarich/watched:/var/app/tmp/imports/watched:rw"
    ];
    ports = [
      "3030:3000/tcp"
    ];
    cmd = [ "bin/rails" "server" "-p" "3000" "-b" "0.0.0.0" ];
    dependsOn = [
      "dawarich_db"
      "dawarich_redis"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--cpus=0.5"
      # NOTE: compose2nix generated the entrypoint inside an array. Docker didn't
      # seem to like this. Had to re-define the entrypoint as a string manually
      # to make Docker happy.
      # "--entrypoint=[\"web-entrypoint.sh\"]"
      "--entrypoint=web-entrypoint.sh"
      "--health-cmd=wget -qO - http://127.0.0.1:3000/api/v1/health | grep -q '\"status\"\\s*:\\s*\"ok\"'"
      "--health-interval=10s"
      "--health-retries=30"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--memory=4294967296b"
      "--network-alias=dawarich"
      "--network=dawarich_dawarich"
    ];
  };
  systemd.services."docker-dawarich" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-dawarich_dawarich.service"
    ];
    requires = [
      "docker-network-dawarich_dawarich.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/dawarich/public"
      "/media/HOMELAB_MEDIA/services/dawarich/watched"
    ];
  };
  virtualisation.oci-containers.containers."dawarich_db" = {
    image = "imresamu/postgis-arm64:14-3.5.2-alpine3.20";
    environmentFiles = [
      config.sops.secrets."compose/dawarich.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/dawarich/data:/var/lib/postgresql/data:rw"
      "/media/HOMELAB_MEDIA/services/dawarich/shared:/var/shared:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--health-cmd=pg_isready -U postgres -d dawarich_development"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=dawarich_db"
      "--network=dawarich_dawarich"
      "--shm-size=1073741824"
    ];
  };
  systemd.services."docker-dawarich_db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-dawarich_dawarich.service"
    ];
    requires = [
      "docker-network-dawarich_dawarich.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/dawarich/data"
      "/media/HOMELAB_MEDIA/services/dawarich/shared"
    ];
  };
  virtualisation.oci-containers.containers."dawarich_redis" = {
    image = "redis:7.0-alpine";
    volumes = [
      "/media/HOMELAB_MEDIA/services/dawarich/shared:/data:rw"
    ];
    cmd = [ "redis-server" ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--health-cmd=[\"redis-cli\", \"--raw\", \"incr\", \"ping\"]"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=dawarich_redis"
      "--network=dawarich_dawarich"
    ];
  };
  systemd.services."docker-dawarich_redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-dawarich_dawarich.service"
    ];
    requires = [
      "docker-network-dawarich_dawarich.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/dawarich/shared"
    ];
  };
  virtualisation.oci-containers.containers."dawarich_sidekiq" = {
    image = "freikin/dawarich:latest";
    environment = {
      "APPLICATION_HOSTS" = "localhost";
      "APPLICATION_PROTOCOL" = "http";
      "BACKGROUND_PROCESSING_CONCURRENCY" = "10";
      "DATABASE_HOST" = "dawarich_db";
      "DATABASE_NAME" = "dawarich_development";
      "DISTANCE_UNIT" = "km";
      "ENABLE_TELEMETRY" = "false";
      "PROMETHEUS_EXPORTER_ENABLED" = "false";
      "PROMETHEUS_EXPORTER_HOST" = "dawarich";
      "PROMETHEUS_EXPORTER_PORT" = "9394";
      "RAILS_ENV" = "development";
      "REDIS_URL" = "redis://dawarich_redis:6379/0";
    };
    environmentFiles = [
      config.sops.secrets."compose/dawarich.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/dawarich/public:/var/app/public:rw"
      "/media/HOMELAB_MEDIA/services/dawarich/watched:/var/app/tmp/imports/watched:rw"
    ];
    cmd = [ "sidekiq" ];
    dependsOn = [
      "dawarich"
      "dawarich_db"
      "dawarich_redis"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--entrypoint=sidekiq-entrypoint.sh"
      "--health-cmd=bundle exec sidekiqmon processes | grep \${HOSTNAME}"
      "--health-interval=10s"
      "--health-retries=30"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=dawarich_sidekiq"
      "--network=dawarich_dawarich"
    ];
  };
  systemd.services."docker-dawarich_sidekiq" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-dawarich_dawarich.service"
    ];
    requires = [
      "docker-network-dawarich_dawarich.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/dawarich/public"
      "/media/HOMELAB_MEDIA/services/dawarich/watched"
    ];
  };

  # Networks
  systemd.services."docker-network-dawarich_dawarich" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f dawarich_dawarich";
    };
    script = ''
      docker network inspect dawarich_dawarich || docker network create dawarich_dawarich
    '';
    partOf = [ "docker-compose-dawarich-root.target" ];
    wantedBy = [ "docker-compose-dawarich-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-dawarich-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
