{ config, pkgs, lib, inputs, ... }:

let
  # The homelab trigger and HOMELAB_MEDIA mount live on pilab, EVERYTHING_ELSE
  # on chocomelt. This key only runs the forced commands in
  # machines/pilab/services/homelab-trigger.nix and machines/chocomelt/default.nix.
  ssh = "${pkgs.openssh}/bin/ssh -i ${config.sops.secrets."homelab_trigger.ssh_key".path} -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10";
  sshPilab = "${ssh} homelab-trigger@pilab.lion-zebra.ts.net";
  sshChocomelt = "${ssh} ritiek@chocomelt.lion-zebra.ts.net";
in

{
  # Home Assistant configuration - SOPS encrypted
  # Edit config: cd /etc/nixos && sops-ssh-home machines/radrubble/services/home-assistant/configuration.yaml
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

  sops.secrets."caldav_password" = {
    restartUnits = [ "home-assistant.service" ];
  };
  sops.secrets."homelab_trigger.ssh_key" = { owner = "hass"; };

  services.openssh.knownHosts."pilab.lion-zebra.ts.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBOR/hkaC38bXYpfyEDWiBLIAzNrvZWTKfCoyC8sU0Q";
  services.openssh.knownHosts."chocomelt.lion-zebra.ts.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKTI0loab2G3JTfgh4J8I2hc7JTb5+G+/xbu1Ng7TaFQ";

  # Sensor publishers (keyberry dht22, pilab bme680) connect over tailscale.
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
      # philips_airpurifier_coap  # Using custom fork from ritiek
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
      "tuya"
      "caldav"
    ];

    extraPackages = ps: with ps; [
      pynacl
      pyjwt
      gtts
      # Required for MCP Server integration
      aiohttp-sse
      mcp
      anyio
      # Required for Tuya integration
      tuya-device-sharing-sdk
      requests
      urllib3
      # Required for Philips Air Purifier component
      aioairctrl
      getmac
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
      input_text = {
        homelab_otp = {
          name = "Homelab OTP";
          mode = "password";
          max = 255;
        };
      };

      shell_command = {
        # Pipe the OTP to pilab, which writes it to /run/homelab-trigger/start.
        # A root-level systemd path unit (homelab-start-trigger) on pilab picks
        # this up and runs homelab-start.
        homelab_start = "${pkgs.bash}/bin/bash -c 'printf \"%s\" \"{{ otp }}\" | ${sshPilab} start'";
      };

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
      };
      command_line = [
        {
          binary_sensor = {
            name = "Homelab Mount Status";
            unique_id = "homelab_mount_status";
            # On only when both HOMELAB_MEDIA (pilab) and EVERYTHING_ELSE (chocomelt) are mounted.
            command = ''[ "$(${sshPilab} mount-status)" = true ] && [ "$(${sshChocomelt})" = true ] && echo true || echo false'';
            payload_on = "true";
            payload_off = "false";
            scan_interval = 30;
          };
        }
      ];

      # Template switch surfaced as an Android Quick Settings tile.
      # - State mirrors the mount status sensor (tile enabled = both drives
      #   mounted). Tapping with one missing reruns homelab-start, which skips
      #   whatever is already mounted.
      # - turn_on (tap when disabled) (re)starts the OTP reply-notification script.
      #   We use script.turn_on (fire-and-forget) instead of calling the script
      #   directly: the script waits up to 24h for a reply, and calling it inline
      #   would keep the switch's turn_on sequence "running" that whole time,
      #   causing every later tap to be dropped with "Already running". The
      #   script itself is mode: restart, so a fresh tap cancels the stale wait
      #   and resends the notification.
      # - turn_off is a no-op so the tile can never accidentally unmount.
      template = [
        {
          switch = [
            {
              name = "Homelab";
              unique_id = "homelab_switch";
              state = "{{ is_state('binary_sensor.homelab_mount_status', 'on') }}";
              icon = "mdi:server";
              turn_on = [
                {
                  action = "script.turn_on";
                  target.entity_id = "script.decrypt_homelab_and_start";
                }
              ];
              turn_off = [];
            }
          ];
        }
      ];

      recorder = {};
      history = {};
      logger = {
        default = "warning";
        logs = {
          "custom_components.philips_airpurifier_coap" = "debug";
          "homeassistant.components.shell_command" = "debug";
          "homeassistant.components.script" = "debug";
          "homeassistant.components.command_line" = "debug";
        };
      };
    };

    # Allow UI configuration changes
    configWritable = true;

  };

  # Copy other custom components to Home Assistant config directory
  systemd.services.home-assistant.serviceConfig.ExecStartPre = [
    # Add automation include after config is copied
    ("+${pkgs.writeShellScript "add-automation-include" ''
      # Wait for config to be copied by the main pre-start script
      sleep 2
      # Add automation include if not present
      if ! grep -q "automation:" /var/lib/hass/configuration.yaml; then
        echo "" >> /var/lib/hass/configuration.yaml
        echo "# Include automations from separate file" >> /var/lib/hass/configuration.yaml
        echo "automation: !include automations.yaml" >> /var/lib/hass/configuration.yaml
        chown hass:hass /var/lib/hass/configuration.yaml
      fi
    ''}")
    ("+${pkgs.writeShellScript "add-scene-include" ''
      # Wait for config to be copied
      sleep 2
      # Add scene include if not present
      if ! grep -q "scene:" /var/lib/hass/configuration.yaml; then
        echo "" >> /var/lib/hass/configuration.yaml
        echo "# Include scenes from separate file" >> /var/lib/hass/configuration.yaml
        echo "scene: !include scenes.yaml" >> /var/lib/hass/configuration.yaml
        chown hass:hass /var/lib/hass/configuration.yaml
      fi
    ''}")
    ("+${pkgs.writeShellScript "add-script-include" ''
      # Wait for config to be copied
      sleep 2
      # Add script include if not present
      if ! grep -q "^script:" /var/lib/hass/configuration.yaml; then
        echo "" >> /var/lib/hass/configuration.yaml
        echo "# Include scripts from separate file" >> /var/lib/hass/configuration.yaml
        echo "script: !include scripts.yaml" >> /var/lib/hass/configuration.yaml
        chown hass:hass /var/lib/hass/configuration.yaml
      fi
    ''}")
    ("+${pkgs.writeShellScript "add-caldav-include" ''
      # Wait for config to be copied
      sleep 2
      # caldav has no UI config flow, so it must be set up via YAML.
      # Write it to a separate included file so the password (read from the
      # sops secret at runtime) never ends up in the Nix store.
      CALDAV_PASSWORD=$(cat ${config.sops.secrets."caldav_password".path})
      cat > /var/lib/hass/caldav.yaml <<EOF
- platform: caldav
  url: "http://pilab.lion-zebra.ts.net:5880/dav.php/"
  username: "ritiek"
  password: "$CALDAV_PASSWORD"
EOF
      chown hass:hass /var/lib/hass/caldav.yaml
      chmod 0600 /var/lib/hass/caldav.yaml
      if ! grep -q "^calendar:" /var/lib/hass/configuration.yaml; then
        echo "" >> /var/lib/hass/configuration.yaml
        echo "# Include CalDAV calendar (Baikal) from separate file" >> /var/lib/hass/configuration.yaml
        echo "calendar: !include caldav.yaml" >> /var/lib/hass/configuration.yaml
        chown hass:hass /var/lib/hass/configuration.yaml
      fi
    ''}")
    ("+${pkgs.writeShellScript "install-dawarich" ''
      mkdir -p /var/lib/hass/custom_components
      if [ ! -d "/var/lib/hass/custom_components/dawarich" ]; then
        cp -r ${pkgs.fetchFromGitHub {
          owner = "AlbinLind";
          repo = "dawarich-home-assistant";
          rev = "main";
          sha256 = "sha256-a7ETEX2XBQSaD+xclDY4yFqafJ7GClbQ1ydU21NY3Es=";
        }}/custom_components/dawarich /var/lib/hass/custom_components/
        chown -R hass:hass /var/lib/hass/custom_components/dawarich
      fi
    ''}")
    ("+${pkgs.writeShellScript "install-philips-airpurifier-coap" ''
      mkdir -p /var/lib/hass/custom_components
      SRC=${pkgs.fetchFromGitHub {
        owner = "kongo09";
        repo = "philips-airpurifier-coap";
        rev = "v0.36.2";
        sha256 = "sha256-aVCfUuwPW+0L+OuOoLV0cPezZVKHtO39p/TK/gy2jdg=";
      }}/custom_components/philips_airpurifier_coap
      DST=/var/lib/hass/custom_components/philips_airpurifier_coap
      if [ ! -f "$DST/.nix-src" ] || [ "$(cat $DST/.nix-src)" != "$SRC" ]; then
        rm -rf "$DST"
        cp -r "$SRC" "$DST"
        echo "$SRC" > "$DST/.nix-src"
        chown -R hass:hass "$DST"
      fi
    ''}")
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
      },
      {
        "url": "/local/homelab-otp-card.js?v=5",
        "type": "module",
        "id": "homelab-otp-card"
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
