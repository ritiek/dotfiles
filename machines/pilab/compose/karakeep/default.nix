# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 2398;
  internalWebUIPort = 12398;

  # Helper script to handle connections
  karakeepConnectionHandler = pkgs.writeShellScript "karakeep-connection-handler" ''
    echo "Connection received at $(date)" >&2

    # Check if Karakeep container is running
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-karakeep.service; then
      echo "Starting Karakeep stack..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-karakeep-chrome.service
      ${pkgs.systemd}/bin/systemctl start docker-karakeep-meilisearch.service
      ${pkgs.systemd}/bin/systemctl start docker-karakeep.service

      # Wait for Karakeep to be ready
      echo "Waiting for Karakeep to start..." >&2
      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -s -f --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/ >/dev/null 2>&1; then
          echo "Karakeep is ready!" >&2
          break
        fi
        if [ $i -eq 60 ]; then
          echo "Karakeep failed to start, sending error page" >&2
          cat << 'EOF'
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html><head><title>Service Starting</title></head>
<body><h1>Karakeep is starting...</h1><p>Please wait a moment and refresh the page.</p></body></html>
EOF
          exit 1
        fi
        sleep 3
      done
    fi

    echo "Karakeep is ready, proxying connection..." >&2
    # Now proxy the connection to the running Karakeep
    exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
  '';

in {
  sops.secrets."compose/karakeep.env" = {
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
  virtualisation.oci-containers.containers."karakeep-chrome" = {
    image = "gcr.io/zenika-hub/alpine-chrome:123";
    environmentFiles = [
      config.sops.secrets."compose/karakeep.env".path
    ];
    cmd = [ "--no-sandbox" "--disable-gpu" "--disable-dev-shm-usage" "--remote-debugging-address=0.0.0.0" "--remote-debugging-port=9222" "--hide-scrollbars" ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=chrome"
      "--network=karakeep_default"
    ];
  };
  systemd.services."docker-karakeep-chrome" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
    ];
    # Bind to root target
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };
  virtualisation.oci-containers.containers."karakeep-meilisearch" = {
    image = "getmeili/meilisearch:v1.13.3";
    environment = {
      "MEILI_NO_ANALYTICS" = "true";
    };
    environmentFiles = [
      config.sops.secrets."compose/karakeep.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/karakeep/meilisearch:/meili_data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=meilisearch"
      "--network=karakeep_default"
    ];
  };
  systemd.services."docker-karakeep-meilisearch" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/karakeep/meilisearch"
    ];
    # Bind to root target
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };
  virtualisation.oci-containers.containers."karakeep" = {
    image = "ghcr.io/karakeep-app/karakeep:release";
    environment = {
      "BROWSER_WEB_URL" = "http://chrome:9222";
      "DATA_DIR" = "/data";
      "MEILI_ADDR" = "http://meilisearch:7700";
    };
    environmentFiles = [
      config.sops.secrets."compose/karakeep.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/karakeep/data:/data:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:3000/tcp"  # Internal port only
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=web"
      "--network=karakeep_default"
    ];
  };
  systemd.services."docker-karakeep" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
      "docker-karakeep-meilisearch.service"
      "docker-karakeep-chrome.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/karakeep/data"
    ];
    # Bind to root target
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start karakeep-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop karakeep-idle-stop.timer || true
    '';
  };

  # Networks
  systemd.services."docker-network-karakeep_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f karakeep_default";
    };
    script = ''
      docker network inspect karakeep_default || docker network create karakeep_default
    '';
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-karakeep-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  # Port listener that starts Karakeep on any connection attempt
  systemd.services."karakeep-autostart" = {
    description = "Karakeep auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting Karakeep auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${karakeepConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/karakeep/meilisearch"
      "/media/HOMELAB_MEDIA/services/karakeep/data"
    ];
    # Bind to root target so it stops when target stops
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-karakeep
  systemd.timers."karakeep-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes, more explicit format
      Persistent = true;
      Unit = "karakeep-idle-stop.service";
    };
  };

  systemd.services."karakeep-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))

      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 5+ minutes, stopping Karakeep stack"
        ${pkgs.systemd}/bin/systemctl stop docker-karakeep.service
        ${pkgs.systemd}/bin/systemctl stop docker-karakeep-meilisearch.service
        ${pkgs.systemd}/bin/systemctl stop docker-karakeep-chrome.service
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping Karakeep running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/karakeep/meilisearch"
      "/media/HOMELAB_MEDIA/services/karakeep/data"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-karakeep-root.target" ];
  };
}
