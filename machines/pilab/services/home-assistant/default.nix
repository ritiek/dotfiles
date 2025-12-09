{ config, pkgs, lib, inputs, ... }:

{
  # Home Assistant configuration - SOPS encrypted
  # Edit config: cd /etc/nixos && sops-ssh-home machines/pilab/services/home-assistant/configuration.yaml
  # All secrets go directly in configuration.yaml (no separate secrets.yaml needed)

  # Decrypt entire HA configuration file
  # systemd.services.home-assistant-config = {
  #   description = "Decrypt Home Assistant configuration";
  #   wantedBy = [ "home-assistant.service" ];
  #   before = [ "home-assistant.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };
  #   script = ''
  #     mkdir -p /var/lib/hass
  #     export SOPS_AGE_KEY_CMD="${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key"
  #     ${pkgs.sops}/bin/sops -d ${./configuration.yaml} > /var/lib/hass/configuration.yaml
  #     chown hass:hass /var/lib/hass/configuration.yaml
  #     chmod 0600 /var/lib/hass/configuration.yaml
  #   '';
  # };

  # sops.secrets."configuration" = {
  #   sopsFile = ./configuration.yaml;
  #   owner = "hass";
  #   group = "hass";
  #   path = "/var/lib/hass/configuration.yaml";
  #   restartUnits = [ "home-assistant.service" ];
  # };

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "0.0.0.0";
        port = 1883;
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  services.home-assistant = {
    enable = true;

    customComponents = with pkgs.home-assistant-custom-components; [
      philips_airpurifier_coap
    ];

    extraComponents = [
      "met"
      "esphome"
      "mqtt"
      "radio_browser"
      "recorder"
      "history"
      "pi_hole"
      "immich"
      "qbittorrent"
      "jellyfin"
      "radarr"
      "sonarr"
      "overseerr"
      "uptime_kuma"
      "mobile_app"
      "http"
      "frontend"
      "raspberry_pi"
      "spotify"
      "tailscale"
      "glances"
      # "geojson"
      "syncthing"
      "mcp_server"
    ];

    extraPackages = ps: with ps; [
      pynacl
      pyjwt
      gtts
      # Required for MCP Server integration
      aiohttp-sse
      mcp
      anyio
      (buildPythonPackage rec {
        pname = "dawarich_api";
        version = "0.4.1";
        pyproject = true;
        build-system = [ setuptools ];
        src = fetchPypi {
          inherit pname version;
          sha256 = "159e7b577f8bbcf992ed5a8439caafddcd9082e5518324fb3202c1fafbbd20b1";
        };
        doCheck = false;
        propagatedBuildInputs = [ aiohttp pydantic ];
      })
    ];

    config = {
      homeassistant = {
        name = "Home";
        latitude = 19.1280123;
        longitude = 72.8590069;
        radius = 60;
        unit_system = "metric";
        time_zone = "Asia/Kolkata";
      };
      lovelace = {
        mode = "storage";
        resources = [
          {
            url = "/local/uptime-card/uptime-card.js";
            type = "module";
          }
        ];
      };
      recorder = {};
      history = {};
      http = {
        server_host = "0.0.0.0";
        server_port = 8123;
        cors_allowed_origins = [ "*" ];
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "100.64.0.0/10"
        ];
        ip_ban_enabled = false;
        base_url = "https://ha.clawsiecats.lol/";
      };
    };

    # Config is managed via SOPS-encrypted file, not writable via UI
    configWritable = false;

  };

  # Copy other custom components to Home Assistant config directory
  systemd.services.home-assistant.serviceConfig.ExecStartPre = [
    # ("+${pkgs.writeShellScript "install-dawarich" ''
    #   mkdir -p /var/lib/hass/custom_components
    #   if [ ! -d "/var/lib/hass/custom_components/dawarich" ]; then
    #     cp -r ${pkgs.fetchFromGitHub {
    #       owner = "AlbinLind";
    #       repo = "dawarich-home-assistant";
    #       rev = "main";
    #       sha256 = "sha256-VliFRJFBut586xWpZSPQ8OrDttoFdrlZyHvktI6AjgM=";
    #     }}/custom_components/dawarich /var/lib/hass/custom_components/
    #     chown -R hass:hass /var/lib/hass/custom_components/dawarich
    #   fi
    # ''}")
    ("+${pkgs.writeShellScript "install-uptime-card" ''
      mkdir -p /var/lib/hass/www/community/uptime-card
      if [ ! -f "/var/lib/hass/www/community/uptime-card/uptime-card.js" ]; then
        ${pkgs.curl}/bin/curl -L -o /var/lib/hass/www/community/uptime-card/uptime-card.js https://github.com/dylandoamaral/uptime-card/releases/download/v0.16.0/uptime-card.js
        ${pkgs.curl}/bin/curl -L -o /var/lib/hass/www/community/uptime-card/uptime-card.js.map https://github.com/dylandoamaral/uptime-card/releases/download/v0.16.0/uptime-card.js.map
        chown -R hass:hass /var/lib/hass/www/community/uptime-card
      fi
    ''}")
    ("+${pkgs.writeShellScript "install-lovelace-resources" ''
      mkdir -p /var/lib/hass/.storage
      cat > /var/lib/hass/.storage/lovelace_resources << 'EOF'
{
  "version": 1,
  "minor_version": 1,
  "key": "lovelace_resources",
  "data": {
    "items": [
      {
        "url": "/local/uptime-card/uptime-card.js",
        "type": "module",
        "id": "uptime-card"
      }
    ]
  }
}
EOF
      chown hass:hass /var/lib/hass/.storage/lovelace_resources
    ''}")
  ];

  networking.firewall.allowedTCPPorts = [ 8123 ];
}
