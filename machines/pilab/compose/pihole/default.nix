# Auto-generated using compose2nix v0.2.3.
{ pkgs, lib, config, homelabMediaPath, ... }:

{
  sops.secrets = {
    "compose/pihole.env" = {
      sopsFile = ./stack.env;
      format = "dotenv";
      restartUnits = [ "docker-pihole.service" ];
    };
    # "compose/pihole-api-key.txt" = {
    #   sopsFile = ./stack.env;
    #   format = "dotenv";
    #   key = "HOMEPAGE_DASHBOARD_API_KEY";
    # };
  };

  networking.firewall = {
    allowedTCPPorts = [
      53
      81
    ];
    allowedUDPPorts = [
      53
      67
      547
      123
    ];
  };

  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."pihole" = {
    image = "pihole/pihole:latest";
    environment = {
      "TZ" = "Asia/Kolkata";
      # If using Docker's default `bridge` network setting the dns listening mode should be set to 'all'
      "FTLCONF_dns_listeningMode" = "all";
      "FTLCONF_webserver_port" = "81";
      "FTLCONF_misc_etc_dnsmasq_d" = "true";
      # Listen on port 5335 so NixOS dnsmasq can own port 53 and forward to us.
      "FTLCONF_dns_port" = "5335";
      # IPv4 only: pilab has no IPv6 route, so v6 upstreams just fail every few minutes.
      "FTLCONF_dns_upstreams" = "1.0.0.1;1.1.1.1";
      # Ask Tailscale MagicDNS for reverse lookups so tailnet clients show up by name.
      "FTLCONF_dns_revServers" = "true,100.64.0.0/10,100.100.100.100";
    };
    environmentFiles = [
      config.sops.secrets."compose/pihole.env".path
    ];
    volumes = [
      "${homelabMediaPath}/services/pihole/data:/etc/pihole:rw"
      "${homelabMediaPath}/services/pihole/dnsmasq.d:/etc/dnsmasq.d:rw"
    ];
    # ports = [
    #   # DNS Ports
    #   "53:53/tcp"
    #   "53:53/udp"
    #   # Default HTTP Port
    #   "81:8080/tcp"
    #   # Default HTTPs Port. FTL will generate a self-signed certificate
    #   "443:443/tcp"
    #   # Uncomment the below if using Pi-hole as your DHCP Server
    #   "67:67/udp"
    #   # Uncomment the line below if you are using Pi-hole as your NTP server
    #   "123:123/udp"
    # ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      # See https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
      "--network=host"
      # Required if you are using Pi-hole as your DHCP server, else not needed
      "--cap-add=NET_ADMIN"
      # Required if you are using Pi-hole as your NTP client to be able to set the host's system time
      "--cap-add=SYS_TIME"
      # Optional, if Pi-hole should get some more processing time
      "--cap-add=SYS_NICE"
    ];
    labels = {
      "homepage.description" = "DNS";
      "homepage.group" = "Services";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:81/admin";
      "homepage.icon" = "pi-hole";
      "homepage.name" = "Pi-Hole";
      # TODO: Make Homepage dashboard widgets work. Currently, one needs to hardcode
      #       the API key in the compose file, which is not ideal. For more info, see:
      #       https://discourse.nixos.org/t/how-to-assign-labels-to-oci-containers-securely/65907
      # "homepage.name" = "$HOMEPAGE_DASHBOARD_API_KEY";
      # "homepage.widget.type" = "pihole";
      # "homepage.widget.url" = "http://host.docker.internal:81/";
      # "homepage.widget.version" = "6";
      # "homepage.widget.key" = config.sops.secrets."compose/pihole-api-key.txt".path;
      # "homepage.widget.key" = "$HOMEPAGE_DASHBOARD_API_KEY";
    };
  };
  systemd.services."docker-pihole" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
      EnvironmentFile = config.sops.secrets."compose/pihole.env".path;
    };
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/pihole"
    ];
  };

  # FTL stops writing its query DB after a transient read error (SQLITE_CORRUPT on
  # 2026-10-27 and 10-29 while DNS kept working) until restarted.
  # ponytail: band-aid restart, drop once pilab's memory pressure is fixed.
  systemd.services.pihole-db-watchdog = {
    description = "Restart Pi-hole if its query DB stops updating";
    path = [ config.virtualisation.docker.package ];
    serviceConfig.Type = "oneshot";
    script = ''
      last=$(docker exec pihole pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db \
        "SELECT CAST(max(timestamp) AS INT) FROM query_storage;") || exit 0
      age=$(( $(date +%s) - ''${last:-0} ))
      echo "Newest query is ''${age}s old"
      if [ "$age" -gt 600 ]; then
        echo "Restarting docker-pihole"
        systemctl try-restart docker-pihole.service
      fi
    '';
  };
  systemd.timers.pihole-db-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15m";
      OnUnitActiveSec = "5m";
    };
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-pihole-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
