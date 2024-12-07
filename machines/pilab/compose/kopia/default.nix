# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, ... }:

{
  sops.secrets."compose/kopia.env" = {
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
  virtualisation.oci-containers.containers."kopia" = {
    image = "kopia/kopia:latest";
    environmentFiles = [
      config.sops.secrets."compose/kopia.env".path
    ];
    volumes = [
      "/:/motionless2:ro"
      "/media/HOMELAB_MEDIA/services/kopia/config:/app/config:rw"
      "kopia_cache:/app/cache:rw"
      "kopia_logs:/app/logs:rw"
    ];
    ports = [
      "51515:51515/tcp"
    ];
    cmd = [
      "server"
      "start"
      "--disable-csrf-token-checks"
      "--insecure"
      "--address=0.0.0.0:51515"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--cap-add=SYS_ADMIN"
      "--device=/dev/fuse:/dev/fuse:rwm"
      "--dns=100.100.100.100"
      "--hostname=pilab"
      "--network-alias=kopia"
      "--network=kopia_default"
      "--privileged"
      "--security-opt=apparmor:unconfined"
    ];
  };
  systemd.services."docker-kopia" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-kopia_default.service"
      "docker-volume-kopia_cache.service"
      "docker-volume-kopia_logs.service"
    ];
    requires = [
      "docker-network-kopia_default.service"
      "docker-volume-kopia_cache.service"
      "docker-volume-kopia_logs.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/"
      "/media/HOMELAB_MEDIA/services/kopia/config"
    ];
  };

  # Networks
  systemd.services."docker-network-kopia_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f kopia_default";
    };
    script = ''
      docker network inspect kopia_default || docker network create kopia_default
    '';
    partOf = [ "docker-compose-kopia-root.target" ];
    wantedBy = [ "docker-compose-kopia-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-kopia_cache" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker volume rm -f kopia_cache";
    };
    script = ''
      docker volume inspect kopia_cache || docker volume create kopia_cache
    '';
    partOf = [ "docker-compose-kopia-root.target" ];
    wantedBy = [ "docker-compose-kopia-root.target" ];
  };
  systemd.services."docker-volume-kopia_logs" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker volume rm -f kopia_logs";
    };
    script = ''
      docker volume inspect kopia_logs || docker volume create kopia_logs
    '';
    partOf = [ "docker-compose-kopia-root.target" ];
    wantedBy = [ "docker-compose-kopia-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-kopia-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
