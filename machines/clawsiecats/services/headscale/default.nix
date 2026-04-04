{ config, lib, pkgs, inputs, ... }:


let
  domain = "clawsiecats.lol";
in
{
  imports = [
    inputs.headplane.nixosModules.headplane
  ];

  sops.secrets = {
    "tailscale.authkey" = {};
    "headscale.noise_private.key" = {
      sopsFile = ./secrets.yaml;
      key = "noise_private.key";
      mode = "0600";
    };
    "headscale.derp_server_private.key" = {
      sopsFile = ./secrets.yaml;
      key = "derp_server_private.key";
      mode = "0600";
    };
    "headscale.db.sqlite" = {
      sopsFile = ./db.sqlite;
      format = "binary";
      mode = "0600";
    };
  };

  environment.persistence."/nix/persist/system" = {
    directories = [
      "/var/lib/headscale"
    ];
  };

  # Seed headscale files from sops secrets on first boot only.
  # sops-nix deploys secrets to /run/secrets/ (tmpfs). The path override to
  # /var/lib/headscale/ does not work because the impermanence bind mount for
  # that directory comes up after sops-nix runs in stage-2, shadowing anything
  # sops wrote there. So we copy manually here, skipping if already persisted.
  systemd.services.headscale-db-seed = {
    description = "Seed headscale data from sops secrets (first boot only)";
    wantedBy = [ "headscale.service" ];
    before = [ "headscale.service" ];
    after = [ "sops-nix.service" "var-lib-headscale.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for src_dest in \
        "${config.sops.secrets."headscale.noise_private.key".path}:/var/lib/headscale/noise_private.key" \
        "${config.sops.secrets."headscale.derp_server_private.key".path}:/var/lib/headscale/derp_server_private.key" \
        "${config.sops.secrets."headscale.db.sqlite".path}:/var/lib/headscale/db.sqlite"
      do
        src="''${src_dest%%:*}"
        dest="''${src_dest##*:}"
        if [ ! -f "$dest" ]; then
          install -m 0600 -o root -g root "$src" "$dest"
        fi
      done
    '';
  };

  systemd.services.tailscaled-autoconnect = {
    after = [ "headscale.service" ];
    wants = [ "headscale.service" ];
    serviceConfig = {
      # On fresh boots, re-auth with headscale (which is also on this machine)
      # can take several minutes: seed → headscale restart → tailscale login.
      # Extend the start timeout well beyond systemd's default 90 s.
      TimeoutStartSec = lib.mkForce "300";
    };
  };

  systemd.services.headplane = {
    after = [ "headscale.service" ];
    wants = [ "headscale.service" ];
    serviceConfig = {
      TimeoutStartSec = lib.mkForce "300";
    };
  };

  services = {
    headscale = {
      enable = true;
      # XXX: Required for Syncthing.
      user = "root";
      # group = "root";
      address = "0.0.0.0";
      port = 8088;
      settings = {
        server_url = "https://controlplane.${domain}";
        # listen_addr is auto-generated from address:port
        # log.level = "debug";
        dns = {
          search_domains = [ "lion-zebra.ts.net" ];
          magic_dns = true;
          nameservers.global = [
            # PiHole (pilab)
            "100.64.0.2"
            # Mullvad
            "194.242.2.2"
            "2a07:e340::2"
          ];
          base_domain = "lion-zebra.ts.net";
        };
        derp = {
          server = {
            enabled = true;
            # TODO: Figure out how to set this to the public IP of clawsiecats
            #       without hardcoding it.
            # ipv4 = "46.8.224.87";
            stun_listen_addr = "0.0.0.0:3479";
            region_code = "headscale";
            region_name = "Headscale Embedded DERP";
            region_id = 999;
            # Setting this to false lets people outside my Headscale network use
            # this DERP relay.
            verify_clients = true;
          };
          # urls = [];
          paths = [];
          auto_update_enabled = false;
          update_frequency = "24h";
        };
      };
    };

    headplane = {
      enable = true;
      # agent.enable = false;
      # agent = {
      #   # As an example only.
      #   # Headplane Agent hasn't yet been ready at the moment of writing the doc.
      #   enable = true;
      #   settings = {
      #     HEADPLANE_AGENT_DEBUG = true;
      #     HEADPLANE_AGENT_HOSTNAME = "localhost";
      #     HEADPLANE_AGENT_TS_SERVER = "https://example.com";
      #     HEADPLANE_AGENT_TS_AUTHKEY = "xxxxxxxxxxxxxx";
      #     HEADPLANE_AGENT_HP_SERVER = "https://example.com/admin/dns";
      #     HEADPLANE_AGENT_HP_AUTHKEY = "xxxxxxxxxxxxxx";
      #   };
      # };
      settings = {
        server = {
          host = "127.0.0.1";
          port = 3000;
          cookie_secret_path = pkgs.writeText "headplane-cookie-secret" "xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX";
          cookie_secure = false;
        };
        headscale = {
          url = "http://127.0.0.1:8088";
          config_strict = true;
        };
        integration = {
          proc.enabled = true;
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      # NGINX and ACME
      80
      443
      # Coturn TURN/STUN
      3479
    ];
    allowedUDPPorts = [
      # DERP STUN
      3479
      41641
    ];
  };
}
