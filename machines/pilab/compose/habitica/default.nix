# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, ... }:

let
  # Configuration
  webUIPort = 3000;
  internalWebUIPort = 13000;

  # Helper script to handle connections
  habiticaConnectionHandler = pkgs.writeShellScript "habitica-connection-handler" ''
    echo "Connection received at $(date)" >&2

    # Check if Habitica containers are running
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-habitica-server.service; then
      echo "Starting Habitica stack..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-habitica-mongo.service
      ${pkgs.systemd}/bin/systemctl start docker-habitica-server.service

      # Wait for Habitica to be ready
      echo "Waiting for Habitica to start..." >&2
      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -s -f --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/ >/dev/null 2>&1; then
          echo "Habitica is ready!" >&2
          break
        fi
        if [ $i -eq 60 ]; then
          echo "Habitica failed to start, sending error page" >&2
          cat << 'EOF'
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html><head><title>Service Starting</title></head>
<body><h1>Habitica is starting...</h1><p>Please wait a moment and refresh the page.</p></body></html>
EOF
          exit 1
        fi
        sleep 3
      done
    fi

    echo "Habitica is ready, proxying connection..." >&2
    # Now proxy the connection to the running Habitica
    exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
  '';

in {
  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."habitica-mongo" = {
    image = "docker.io/mongo:5.0";
    volumes = [
      "/media/HOMELAB_MEDIA/services/habitica/db:/data/db:rw"
      "/media/HOMELAB_MEDIA/services/habitica/dbconf:/data/configdb:rw"
    ];
    cmd = [ "--replSet" "rs" "--bind_ip_all" "--port" "27017" ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--health-cmd=echo \"try { rs.status() } catch (err) { rs.initiate() }\" | mongosh --port 27017 --quiet"
      "--health-interval=10s"
      "--health-retries=30"
      "--health-start-interval=1s"
      "--health-start-period=0s"
      "--health-timeout=30s"
      "--hostname=mongo"
      "--network-alias=mongo"
      "--network-alias=mongo"
      "--network=habitica_habitica"
    ];
  };
  systemd.services."docker-habitica-mongo" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-habitica_habitica.service"
    ];
    requires = [
      "docker-network-habitica_habitica.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/habitica/db"
      "/media/HOMELAB_MEDIA/services/habitica/dbconf"
    ];
    # Bind to root target
    partOf = [ "docker-compose-habitica-root.target" ];
    wantedBy = [ "docker-compose-habitica-root.target" ];
  };
  virtualisation.oci-containers.containers."habitica-server" = {
    image = "docker.io/awinterstein/habitica-server:latest";
    environment = {
      "BASE_URL" = "http://127.0.0.1:8080";
      "INVITE_ONLY" = "false";
      "NODE_DB_URI" = "mongodb://mongo/habitica";
    };
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:3000/tcp"  # Internal port only
    ];
    dependsOn = [
      "habitica-mongo"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=server"
      "--network=habitica_habitica"
    ];
  };
  systemd.services."docker-habitica-server" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    after = [
      "docker-network-habitica_habitica.service"
    ];
    requires = [
      "docker-network-habitica_habitica.service"
    ];
    # Bind to root target
    partOf = [ "docker-compose-habitica-root.target" ];
    wantedBy = [ "docker-compose-habitica-root.target" ];
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start habitica-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop habitica-idle-stop.timer || true
    '';
  };

  # Networks
  systemd.services."docker-network-habitica_habitica" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f habitica_habitica";
    };
    script = ''
      docker network inspect habitica_habitica || docker network create habitica_habitica --driver=bridge
    '';
    partOf = [ "docker-compose-habitica-root.target" ];
    wantedBy = [ "docker-compose-habitica-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-habitica-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  # Port listener that starts Habitica on any connection attempt
  systemd.services."habitica-autostart" = {
    description = "Habitica auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting Habitica auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${habiticaConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/habitica/db"
      "/media/HOMELAB_MEDIA/services/habitica/dbconf"
    ];
    # Bind to root target so it stops when target stops
    partOf = [ "docker-compose-habitica-root.target" ];
    wantedBy = [ "docker-compose-habitica-root.target" ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-habitica-server
  systemd.timers."habitica-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes, more explicit format
      Persistent = true;
      Unit = "habitica-idle-stop.service";
    };
  };

  systemd.services."habitica-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))

      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 5+ minutes, stopping Habitica stack"
        ${pkgs.systemd}/bin/systemctl stop docker-habitica-server.service
        ${pkgs.systemd}/bin/systemctl stop docker-habitica-mongo.service
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping Habitica running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/habitica/db"
      "/media/HOMELAB_MEDIA/services/habitica/dbconf"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-habitica-root.target" ];
  };
}
