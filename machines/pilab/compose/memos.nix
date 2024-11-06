# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, ... }:

{
  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."memos" = {
    image = "neosmemo/memos:latest";
    volumes = [
      "/media/services/memos:/var/opt/memos:rw"
    ];
    ports = [
      "5230:5230/tcp"
    ];
    user = "1000:1000";
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=memos"
      "--network=memos_default"
    ];
  };
  systemd.services."docker-memos" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-memos_default.service"
    ];
    requires = [
      "docker-network-memos_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/services/memos"
    ];
  };

  # Networks
  systemd.services."docker-network-memos_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f memos_default";
    };
    script = ''
      docker network inspect memos_default || docker network create memos_default
    '';
    partOf = [ "docker-compose-memos-root.target" ];
    wantedBy = [ "docker-compose-memos-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-memos-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
