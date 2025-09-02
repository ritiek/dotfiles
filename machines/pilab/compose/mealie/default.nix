# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 9091;
  internalWebUIPort = 19091;

  # Helper script to handle connections
  mealieConnectionHandler = pkgs.writeShellScript "mealie-connection-handler" ''
    echo "Connection received at $(date)" >&2

    # Check if Mealie container is running
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-mealie.service; then
      echo "Starting Mealie stack..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-mealie.service
      ${pkgs.systemd}/bin/systemctl start docker-mealie_dev_postgres.service
      ${pkgs.systemd}/bin/systemctl start docker-mealie_dev_mailpit.service

      # Wait for Mealie to be ready
      echo "Waiting for Mealie to start..." >&2
      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -s -f --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/ >/dev/null 2>&1; then
          echo "Mealie is ready!" >&2
          break
        fi
        if [ $i -eq 60 ]; then
          echo "Mealie failed to start, sending error page" >&2
          cat << 'EOF'
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html><head><title>Service Starting</title></head>
<body><h1>Mealie is starting...</h1><p>Please wait a moment and refresh the page.</p></body></html>
EOF
          exit 1
        fi
        sleep 3
      done
    fi

    echo "Mealie is ready, proxying connection..." >&2
    # Now proxy the connection to the running Mealie
    exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
  '';

in {
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
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start mealie-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop mealie-idle-stop.timer || true
    '';
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

  # Port listener that starts Mealie on any connection attempt
  systemd.services."mealie-autostart" = {
    description = "Mealie auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting Mealie auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${mealieConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/mealie/data"
      "/media/HOMELAB_MEDIA/services/mealie/postgresql"
    ];
    # Bind to root target so it stops when target stops
    partOf = [ "docker-compose-mealie-root.target" ];
    wantedBy = [ "docker-compose-mealie-root.target" ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-mealie
  systemd.timers."mealie-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes, more explicit format
      Persistent = true;
      Unit = "mealie-idle-stop.service";
    };
  };

  systemd.services."mealie-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))

      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 5+ minutes, stopping Mealie stack"
        ${pkgs.systemd}/bin/systemctl stop docker-mealie.service
        ${pkgs.systemd}/bin/systemctl stop docker-mealie_dev_postgres.service
        ${pkgs.systemd}/bin/systemctl stop docker-mealie_dev_mailpit.service
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping Mealie running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/mealie/data"
      "/media/HOMELAB_MEDIA/services/mealie/postgresql"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-mealie-root.target" ];
  };
}
