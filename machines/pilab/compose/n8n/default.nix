# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, homelabMediaPath, ... }:

{
  sops.secrets = {
    "compose/n8n.env" = {
      sopsFile = ./stack.env;
      format = "dotenv";
    };
  };

  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."n8n" = {
    image = "docker.n8n.io/n8nio/n8n";
    environmentFiles = [
      config.sops.secrets."compose/n8n.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/n8n/storage:/home/node/.n8n:rw"
    ];
    ports = [
      "5678:5678/tcp"
    ];
    dependsOn = [
      "n8n-postgres"
      "n8n-redis"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=n8n"
      "--network=n8n_default"
    ];
    labels = {
      "homepage.description" = "Workflow automations";
      "homepage.group" = "Services";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:5678";
      "homepage.icon" = "n8n";
      "homepage.name" = "n8n";
    };
  };
  systemd.services."docker-n8n" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-n8n_default.service"
    ];
    requires = [
      "docker-network-n8n_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/n8n/storage"
    ];
  };
  virtualisation.oci-containers.containers."n8n-worker" = {
    image = "docker.n8n.io/n8nio/n8n";
    environmentFiles = [
      config.sops.secrets."compose/n8n.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/n8n/storage:/home/node/.n8n:rw"
    ];
    cmd = [ "worker" ];
    dependsOn = [
      "n8n"
      "n8n-postgres"
      "n8n-redis"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=n8n-worker"
      "--network=n8n_default"
    ];
  };
  systemd.services."docker-n8n-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-n8n_default.service"
    ];
    requires = [
      "docker-network-n8n_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/n8n/storage"
    ];
  };
  virtualisation.oci-containers.containers."n8n-postgres" = {
    image = "postgres:16";
    environmentFiles = [
      config.sops.secrets."compose/n8n.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/n8n/db:/var/lib/postgresql/data:rw"
      "${homelabMediaPath}/services/n8n/init-data.sh:/docker-entrypoint-initdb.d/init-data.sh:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--health-cmd=pg_isready -h localhost -U n8n-the-admin-way -d n8nlikesdb"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=postgres"
      "--network=n8n_default"
    ];
  };
  systemd.services."docker-n8n-postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-n8n_default.service"
    ];
    requires = [
      "docker-network-n8n_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/n8n/db"
      "${homelabMediaPath}/services/n8n/init-data.sh"
    ];
  };
  virtualisation.oci-containers.containers."n8n-redis" = {
    image = "redis:6-alpine";
    environmentFiles = [
      config.sops.secrets."compose/n8n.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/n8n/redis:/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--health-cmd=[\"redis-cli\", \"ping\"]"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=redis"
      "--network=n8n_default"
    ];
  };
  systemd.services."docker-n8n-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-n8n_default.service"
    ];
    requires = [
      "docker-network-n8n_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/n8n/redis"
    ];
  };

  # Networks
  systemd.services."docker-network-n8n_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f n8n_default";
    };
    script = ''
      docker network inspect n8n_default || docker network create n8n_default
    '';
    partOf = [ "docker-compose-n8n-root.target" ];
    wantedBy = [ "docker-compose-n8n-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-n8n-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
