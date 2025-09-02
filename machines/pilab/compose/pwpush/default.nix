# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, config, ... }:

let
  # Configuration
  webUIPort = 5100;
  internalWebUIPort = 15100;

  # Helper script to handle connections
  pwpushConnectionHandler = pkgs.writeShellScript "pwpush-connection-handler" ''
    echo "Connection received at $(date)" >&2

    # Check if Password Pusher container is running
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-pwpush.service; then
      echo "Starting Password Pusher stack..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-pwpush-db.service
      ${pkgs.systemd}/bin/systemctl start docker-pwpush.service
      ${pkgs.systemd}/bin/systemctl start docker-pwpush-worker.service

      # Wait for Password Pusher to be ready
      echo "Waiting for Password Pusher to start..." >&2
      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -s -f --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/ >/dev/null 2>&1; then
          echo "Password Pusher is ready!" >&2
          break
        fi
        if [ $i -eq 60 ]; then
          echo "Password Pusher failed to start, sending error page" >&2
          cat << 'EOF'
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html><head><title>Service Starting</title></head>
<body><h1>Password Pusher is starting...</h1><p>Please wait a moment and refresh the page.</p></body></html>
EOF
          exit 1
        fi
        sleep 3
      done
    fi

    echo "Password Pusher is ready, proxying connection..." >&2
    # Now proxy the connection to the running Password Pusher
    exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
  '';

in {
  sops.secrets."compose/pwpush.env" = {
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
  virtualisation.oci-containers.containers."pwpush-db" = {
    image = "docker.io/postgres:15";
    environmentFiles = [
      config.sops.secrets."compose/pwpush.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/pwpush/pgdata:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=db"
      "--network=pwpush_default"
    ];
  };
  systemd.services."docker-pwpush-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-pwpush_default.service"
    ];
    requires = [
      "docker-network-pwpush_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/pwpush/pgdata"
    ];
    # Bind to root target
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };
  virtualisation.oci-containers.containers."pwpush" = {
    # image = "docker.io/pglombardo/pwpush:latest";
    # Using stable for ARM 64 support for now:
    image = "docker.io/pglombardo/pwpush:stable";
    environmentFiles = [
      config.sops.secrets."compose/pwpush.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/pwpush/settings.yml:/opt/PasswordPusher/config/settings.yml:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:5100/tcp"  # Internal port only
    ];
    dependsOn = [
      "pwpush-db"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=pwpush"
      "--network=pwpush_default"
    ];
  };
  # Restore original docker-pwpush service dependencies
  systemd.services."docker-pwpush" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-pwpush_default.service"
    ];
    requires = [
      "docker-network-pwpush_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/pwpush/settings.yml"
    ];
    # Bind to root target
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start pwpush-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop pwpush-idle-stop.timer || true
    '';
  };
  virtualisation.oci-containers.containers."pwpush-worker" = {
    image = "docker.io/pglombardo/pwpush-worker:stable";
    environmentFiles = [
      config.sops.secrets."compose/pwpush.env".path
    ];
    dependsOn = [
      "pwpush-db"
      "pwpush"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=worker"
      "--network=pwpush_default"
    ];
  };
  systemd.services."docker-pwpush-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "docker-network-pwpush_default.service"
    ];
    requires = [
      "docker-network-pwpush_default.service"
    ];
    # Bind to root target
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };

  # Networks
  systemd.services."docker-network-pwpush_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f pwpush_default";
    };
    script = ''
      docker network inspect pwpush_default || docker network create pwpush_default
    '';
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
  };

  # Root service
  systemd.targets."docker-compose-pwpush-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  # Port listener that starts Password Pusher on any connection attempt
  systemd.services."pwpush-autostart" = {
    description = "Password Pusher auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting Password Pusher auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${pwpushConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/pwpush/pgdata"
      "/media/HOMELAB_MEDIA/services/pwpush/settings.yml"
    ];
    # Bind to root target so it stops when target stops
    partOf = [ "docker-compose-pwpush-root.target" ];
    wantedBy = [ "docker-compose-pwpush-root.target" ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-pwpush
  systemd.timers."pwpush-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes, more explicit format
      Persistent = true;
      Unit = "pwpush-idle-stop.service";
    };
  };

  systemd.services."pwpush-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))

      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 5+ minutes, stopping Password Pusher stack"
        ${pkgs.systemd}/bin/systemctl stop docker-pwpush.service
        ${pkgs.systemd}/bin/systemctl stop docker-pwpush-worker.service
        ${pkgs.systemd}/bin/systemctl stop docker-pwpush-db.service
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping Password Pusher running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/pwpush/pgdata"
      "/media/HOMELAB_MEDIA/services/pwpush/settings.yml"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-pwpush-root.target" ];
  };
}
