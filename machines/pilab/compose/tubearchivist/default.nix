# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 8454;
  internalWebUIPort = 18454;

  # Helper script to handle connections
  tubearchivistConnectionHandler = pkgs.writeShellScript "tubearchivist-connection-handler" ''
    echo "Connection received at $(date)" >&2
    
    # Check if TubeArchivist container is running
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-tubearchivist.service; then
      echo "Starting TubeArchivist stack..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-compose-tubearchivist-root.target
      
      # Wait for TubeArchivist to be ready
      echo "Waiting for TubeArchivist to start..." >&2
      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -s -f --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/health >/dev/null 2>&1; then
          echo "TubeArchivist is ready!" >&2
          break
        fi
        if [ $i -eq 60 ]; then
          echo "TubeArchivist failed to start, sending error page" >&2
          cat << 'EOF'
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html><head><title>Service Starting</title></head>
<body><h1>TubeArchivist is starting...</h1><p>Please wait a moment and refresh the page. This may take up to 2 minutes for all services to initialize.</p></body></html>
EOF
          exit 1
        fi
        sleep 2
      done
    fi
    
    echo "TubeArchivist is ready, proxying connection..." >&2
    # Now proxy the connection to the running TubeArchivist
    exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
  '';

in {
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
      "/media/HOMELAB_MEDIA/services/tubearchivist/es:/usr/share/elasticsearch/data:rw"
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
      "/media/HOMELAB_MEDIA/services/tubearchivist/es"
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
      "/media/HOMELAB_MEDIA/services/tubearchivist/cache:/cache:rw"
      "/media/HOMELAB_MEDIA/services/tubearchivist/videos:/youtube:rw"
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
    labels = {
      "homepage.description" = "Tube Archivist";
      "homepage.group" = "Services";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:${toString webUIPort}";
      "homepage.icon" = "tube-archivist";
      "homepage.name" = "Tube Archivist";
    };
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
      "/media/HOMELAB_MEDIA/services/tubearchivist/cache"
      "/media/HOMELAB_MEDIA/services/tubearchivist/videos"
    ];
    partOf = [ "docker-compose-tubearchivist-root.target" ];
    wantedBy = [ "docker-compose-tubearchivist-root.target" ];
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start tubearchivist-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop tubearchivist-idle-stop.timer || true
    '';
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

  # Port listener that starts TubeArchivist on any connection attempt
  systemd.services."tubearchivist-autostart" = {
    description = "TubeArchivist auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting TubeArchivist auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${tubearchivistConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/tubearchivist/cache"
      "/media/HOMELAB_MEDIA/services/tubearchivist/videos"
      "/media/HOMELAB_MEDIA/services/tubearchivist/es"
    ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-tubearchivist
  systemd.timers."tubearchivist-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/10";  # Every 10 minutes (TubeArchivist is heavier than Navidrome)
      Persistent = true;
      Unit = "tubearchivist-idle-stop.service";
    };
  };

  systemd.services."tubearchivist-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))
      
      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 10+ minutes, stopping TubeArchivist stack"
        ${pkgs.systemd}/bin/systemctl stop docker-compose-tubearchivist-root.target
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping TubeArchivist running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/tubearchivist/cache"
      "/media/HOMELAB_MEDIA/services/tubearchivist/videos"
      "/media/HOMELAB_MEDIA/services/tubearchivist/es"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-tubearchivist-root.target" ];
  };
}
