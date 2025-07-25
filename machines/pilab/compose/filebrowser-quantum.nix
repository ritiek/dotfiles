# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, ... }:

{
  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."filebrowser-quantum" = {
    image = "gtstef/filebrowser";
    volumes = [
      "/media/HOMELAB_MEDIA/services:/media/HOMELAB_MEDIA/services:ro"
      "/media/HOMELAB_MEDIA/files:/media/HOMELAB_MEDIA/files:rw"
      "/media/HOMELAB_MEDIA/services/filebrowser-quantum/config.yaml:/home/filebrowser/config.yaml:rw"
      "/media/HOMELAB_MEDIA/services/filebrowser-quantum/database.db:/home/filebrowser/data/database.db:rw"
      # "/media/HOMELAB_MEDIA/services/filebrowser-quantum/frontend:/home/frontend:rw"
    ];
    ports = [
      "8188:80/tcp"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--hostname=filebrowser"
      "--network-alias=filebrowser"
      "--network=filebrowser_default"
    ];
    labels = {
      "homepage.description" = "Filebrowser";
      "homepage.group" = "Services";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:8188/";
      "homepage.icon" = "filebrowser";
      "homepage.name" = "FileBrowser Quantum";
    };
  };
  systemd.services."docker-filebrowser-quantum" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-filebrowser_default.service"
    ];
    requires = [
      "docker-network-filebrowser_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/filebrowser-quantum/config.yaml"
      "/media/HOMELAB_MEDIA/services/filebrowser-quantum/frontend"
    ];
  };

  # Networks
  systemd.services."docker-network-filebrowser_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f filebrowser_default";
    };
    script = ''
      docker network inspect filebrowser_default || docker network create filebrowser_default
    '';
    partOf = [ "docker-compose-filebrowser-quantum-root.target" ];
    wantedBy = [ "docker-compose-filebrowser-quantum-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-filebrowser-quantum-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
