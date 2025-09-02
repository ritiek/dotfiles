# Auto-generated using compose2nix v0.3.1.
{ config, pkgs, lib, ... }:

let
  # Configuration
  webUIPort = 3020;
  internalWebUIPort = 13020;

  # Helper script to handle connections
  ollamaWebUIConnectionHandler = pkgs.writeShellScript "ollama-webui-connection-handler" ''
    echo "Connection received at $(date)" >&2

    # Check if Open-WebUI container is running
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-open-webui.service; then
      echo "Starting Ollama & Open-WebUI stack..." >&2
      ${pkgs.systemd}/bin/systemctl start docker-ollama.service
      ${pkgs.systemd}/bin/systemctl start docker-open-webui.service

      # Wait for Open-WebUI to be ready
      echo "Waiting for Open-WebUI to start..." >&2
      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -s -f --connect-timeout 2 http://127.0.0.1:${toString internalWebUIPort}/ >/dev/null 2>&1; then
          echo "Open-WebUI is ready!" >&2
          break
        fi
        if [ $i -eq 60 ]; then
          echo "Open-WebUI failed to start, sending error page" >&2
          cat << 'EOF'
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<!DOCTYPE html>
<html><head><title>Service Starting</title></head>
<body><h1>Ollama & Open-WebUI is starting...</h1><p>Please wait a moment and refresh the page.</p></body></html>
EOF
          exit 1
        fi
        sleep 3
      done
    fi

    echo "Open-WebUI is ready, proxying connection..." >&2
    # Now proxy the connection to the running Open-WebUI
    exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalWebUIPort}
  '';

in {
  sops.secrets."compose/ollama-webui.env" = {
    sopsFile = ./stack.env;
    format = "dotenv";
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."ollama" = {
    image = "ollama/ollama:latest";
    volumes = [
      "/media/HOMELAB_MEDIA/services/ollama-webui/ollama:/root/.ollama:rw"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=ollama"
      "--network=ollama-webui_default"
    ];
  };
  systemd.services."docker-ollama" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-ollama-webui_default.service"
    ];
    requires = [
      "docker-network-ollama-webui_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/ollama-webui/ollama"
    ];
    # Bind to root target
    partOf = [ "docker-compose-ollama-webui-root.target" ];
    wantedBy = [ "docker-compose-ollama-webui-root.target" ];
  };
  virtualisation.oci-containers.containers."open-webui" = {
    image = "ghcr.io/open-webui/open-webui:main";
    # environment = {
    #   "OLLAMA_BASE_URL" = "http://ollama:11434";
    # };
    environmentFiles = [
      config.sops.secrets."compose/ollama-webui.env".path
    ];
    volumes = [
      "/media/HOMELAB_MEDIA/services/ollama-webui/open-webui:/app/backend/data:rw"
    ];
    ports = [
      "127.0.0.1:${toString internalWebUIPort}:8080/tcp"  # Internal port only
    ];
    # Removed dependsOn to make services independent
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--network-alias=open-webui"
      "--network=ollama-webui_default"
    ];
  };
  systemd.services."docker-open-webui" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-ollama-webui_default.service"
    ];
    requires = [
      "docker-network-ollama-webui_default.service"
    ];
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/ollama-webui/open-webui"
    ];
    # Bind to root target
    partOf = [ "docker-compose-ollama-webui-root.target" ];
    wantedBy = [ "docker-compose-ollama-webui-root.target" ];
    # Start timer when service starts, stop when service stops
    postStart = ''
      ${pkgs.systemd}/bin/systemctl start ollama-webui-idle-stop.timer
    '';
    preStop = ''
      ${pkgs.systemd}/bin/systemctl stop ollama-webui-idle-stop.timer || true
    '';
  };

  # Networks
  systemd.services."docker-network-ollama-webui_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f ollama-webui_default";
    };
    script = ''
      docker network inspect ollama-webui_default || docker network create ollama-webui_default
    '';
    partOf = [ "docker-compose-ollama-webui-root.target" ];
    wantedBy = [ "docker-compose-ollama-webui-root.target" ];
  };

  # Builds
  # systemd.services."docker-build-open-webui" = {
  #   path = [ pkgs.docker pkgs.git ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     TimeoutSec = 300;
  #   };
  #   script = ''
  #     cd /etc/nixos
  #     docker build -t ghcr.io/open-webui/open-webui:main --build-arg OLLAMA_BASE_URL=/ollama .
  #   '';
  # };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-ollama-webui-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };

  # Port listener that starts Ollama & Open-WebUI on any connection attempt
  systemd.services."ollama-webui-autostart" = {
    description = "Ollama & Open-WebUI auto-start on connection";
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      echo "Starting Ollama & Open-WebUI auto-start proxy on port ${toString webUIPort}..."
      exec ${pkgs.socat}/bin/socat TCP4-LISTEN:${toString webUIPort},reuseaddr,fork EXEC:${ollamaWebUIConnectionHandler}
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/ollama-webui/ollama"
      "/media/HOMELAB_MEDIA/services/ollama-webui/open-webui"
    ];
    # Bind to root target so it stops when target stops
    partOf = [ "docker-compose-ollama-webui-root.target" ];
    wantedBy = [ "docker-compose-ollama-webui-root.target" ];
    after = [ "docker.service" ];
  };

  # Timer-based service to stop when idle - started manually by docker-open-webui
  systemd.timers."ollama-webui-idle-stop" = {
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes, more explicit format
      Persistent = true;
      Unit = "ollama-webui-idle-stop.service";
    };
  };

  systemd.services."ollama-webui-idle-stop" = {
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check for active connections (both proxy port and internal port)
      proxy_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString webUIPort}" | grep ESTABLISHED | wc -l)
      internal_connections=$(${pkgs.unixtools.netstat}/bin/netstat -an | grep ":${toString internalWebUIPort}" | grep ESTABLISHED | wc -l)
      total_connections=$((proxy_connections + internal_connections))

      if [ "$total_connections" -eq 0 ]; then
        echo "$(date): No active connections for 5+ minutes, stopping Ollama & Open-WebUI stack"
        ${pkgs.systemd}/bin/systemctl stop docker-open-webui.service
        ${pkgs.systemd}/bin/systemctl stop docker-ollama.service
        # Timer will automatically stop due to partOf dependency
      else
        echo "$(date): $total_connections active connections, keeping Ollama & Open-WebUI running"
      fi
    '';
    unitConfig.RequiresMountsFor = [
      "/media/HOMELAB_MEDIA/services/ollama-webui/ollama"
      "/media/HOMELAB_MEDIA/services/ollama-webui/open-webui"
    ];
    # Also bind to root target for additional safety
    partOf = [ "docker-compose-ollama-webui-root.target" ];
  };
}
