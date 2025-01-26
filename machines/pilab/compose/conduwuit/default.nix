# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, ... }:

{
  sops.secrets."compose/conduwuit.env" = {
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
  virtualisation.oci-containers.containers."conduwuit" = {
    image = "girlbossceo/conduwuit:latest";
    environmentFiles = [
      config.sops.secrets."compose/conduwuit.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/conduwuit/data:/var/lib/matrix-conduit:rw"
    ];
    ports = [
      "6168:6168/tcp"
    ];
    user = "1001:1001";
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=conduit"
      "--network=conduwuit_default"
    ];
    labels = {
      "homepage.description" = "Conduwuit Homeserver";
      "homepage.group" = "Services";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:6168";
      "homepage.icon" = "matrix";
      "homepage.name" = "Matrix";
    };
  };
  systemd.services."docker-conduwuit" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-conduwuit_default.service"
    ];
    requires = [
      "docker-network-conduwuit_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/conduwuit/data"
    ];
  };

  # Networks
  systemd.services."docker-network-conduwuit_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f conduwuit_default";
    };
    script = ''
      docker network inspect conduwuit_default || docker network create conduwuit_default
    '';
    partOf = [ "docker-compose-conduwuit-root.target" ];
    wantedBy = [ "docker-compose-conduwuit-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-conduwuit-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
