# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, ... }:

let
  # Configuration
  webUIPort = 4533;
  internalWebUIPort = 14533;

  # Helper script to handle HTTP connections and show loading page
  navidromeConnectionHandler = pkgs.writeShellScript "navidrome-connection-handler" ''
    echo "Connection received at $(date)" >&2

    # Check if Navidrome container is running first
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-navidrome.service; then
      echo "Starting Navidrome container..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-navidrome.service

      # Send loading page immediately
      cat << 'EOF'
HTTP/1.1 200 OK
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html>
<head>
    <title>Navidrome - Starting</title>
    <meta http-equiv="refresh" content="3">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 2s linear infinite; margin: 20px auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <h1>Navidrome is starting...</h1>
    <div class="spinner"></div>
    <p>Please wait while the service loads. This page will refresh automatically.</p>
    <p><a href="/">Click here to refresh manually</a></p>
</body>
</html>
EOF
      exit 0
    fi

    # Service is already running, check if it's responding
    if ${pkgs.curl}/bin/curl -s --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/ >/dev/null 2>&1; then
      echo "Navidrome is ready, proxying connection..." >&2
      # Forward the entire HTTP connection to the actual service
      exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
    else
      echo "Navidrome not responding, sending loading page..." >&2
      # Send loading page
      cat << 'EOF'
HTTP/1.1 200 OK
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html>
<head>
    <title>Navidrome - Starting</title>
    <meta http-equiv="refresh" content="2">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 2s linear infinite; margin: 20px auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <h1>Navidrome is starting...</h1>
    <div class="spinner"></div>
    <p>Service is warming up. This page will refresh automatically.</p>
</body>
</html>
EOF
    fi
  '';

in {
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers."navidrome" = {
    image = "deluan/navidrome:latest";
    environment = {
      "ND_BASEURL" = "";
      "ND_LOGLEVEL" = "info";
      "ND_SCANSCHEDULE" = "1h";
      "ND_SESSIONTIMEOUT" = "24h";
    };
    volumes = [
      "/media/HOMELAB_MEDIA/services/navidrome:/data:rw"
      "/media/HOMELAB_MEDIA/services/spotdl:/music:ro"
    ];
    ports = [ "127.0.0.1:${toString internalWebUIPort}:4533/tcp" ];  # Internal port only
    user = "1000:1000";
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=navidrome"
      "--network=navidrome_default"
    ];
  };

  # Network
  systemd.services."docker-network-navidrome_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f navidrome_default";
    };
    script = ''
      docker network inspect navidrome_default || docker network create navidrome_default
    '';
    partOf = [ "docker-compose-navidrome-root.target" ];
    wantedBy = [ "docker-compose-navidrome-root.target" ];
  };

  # Restore original docker-navidrome service dependencies
  systemd.services."docker-navidrome" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-navidrome_default.service"
    ];
    requires = [
      "docker-network-navidrome_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/navidrome"
      "/media/HOMELAB_MEDIA/services/spotdl"
    ];
    # Bind to root target
    partOf = [ "docker-compose-navidrome-root.target" ];
    wantedBy = [ "docker-compose-navidrome-root.target" ];
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start navidrome-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop navidrome-idle-stop.timer || true
    '';
  };

  # Root service
  systemd.targets."docker-compose-navidrome-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  # Port listener that starts Navidrome on any connection attempt
  systemd.services."navidrome-autostart" = {
    description = "Navidrome auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting Navidrome auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${navidromeConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/navidrome"
      "/media/HOMELAB_MEDIA/services/spotdl"
    ];
    # Bind to root target so it stops when target stops
    partOf = [ "docker-compose-navidrome-root.target" ];
    wantedBy = [ "docker-compose-navidrome-root.target" ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-navidrome
  systemd.timers."navidrome-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes, more explicit format
      Persistent = true;
      Unit = "navidrome-idle-stop.service";
    };
  };

  systemd.services."navidrome-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))

      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 5+ minutes, stopping Navidrome"
        ${pkgs.systemd}/bin/systemctl stop docker-navidrome.service
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping Navidrome running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/navidrome"
      "/media/HOMELAB_MEDIA/services/spotdl"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-navidrome-root.target" ];
  };
}
