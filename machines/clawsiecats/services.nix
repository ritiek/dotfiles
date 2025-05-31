{ config, lib, pkgs, inputs, ... }:

let
  domain = "clawsiecats.omg.lol";
in
{
  imports = [
    inputs.headplane.nixosModules.headplane
  ];

  environment.persistence."/nix/persist/system" = {
    directories = [
      "/var/lib/acme"
      "/var/lib/jitsi-meet"
      "/var/lib/prosody"
      "/var/lib/headscale"
      # {
      #     directory = "/var/lib/prosody";
      #     user = config.ids.uids.prosody;
      #     group = config.ids.gids.prosody;
      #     mode = "u=rwx,g=rx,o=";
      # }
      "/var/lib/syncthing"
      # {
      #     directory = "/var/lib/syncthing";
      #     # user = config.ids.uids.syncthing;
      #     # group = config.ids.gids.syncthing;
      #     user = "syncthing";
      #     group = "syncthing";
      #     mode = "u=rwx,g=rx,o=";
      # }
    ];
    files = [ ];
  };
  sops.secrets = {
    "jitsi.htpasswd" = {
      owner = "nginx";
    };
    "syncplay.password" = {};
  };

  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8043"
  ];

  # systemd.tmpfiles.settings."10-syncthing" = {
  #   "/var/lib/syncthing".d = {
  #     mode = "0700";
  #     user = config.ids.uids.syncthing;
  #     group = config.ids.gids.syncthing;
  #   };
  # };

  services = {
    jitsi-meet = {
      enable = true;
      hostName = "jitsi.${domain}";
      config = {
        enableInsecureRoomNameWarning = true;
        fileRecordingsEnabled = false;
        liveStreamingEnabled = false;
        prejoinPageEnabled = true;
      };
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
      };
    };

    jitsi-videobridge.openFirewall = true;

    syncplay = {
      enable = true;
      passwordFile = config.sops.secrets."syncplay.password".path;
      useACMEHost = "syncplay.${domain}";
    };

    # invidious = {
    #   enable = true;
    #   domain = "invidious.${domain}";
    #   nginx.enable = true;
    # };

    headscale = {
      enable = true;
      user = "root";
      # group = "root";
      settings = {
        server_url = "https://${domain}";
        listen_addr = "127.0.0.1:8080";
        # listen_addr = "0.0.0.0:8080";
        dns = {
          search_domains = [ "lion-zebra.ts.net" ];
          magic_dns = true;
          nameservers.global = [
            # PiHole
            # "100.76.250.31"
            "100.64.0.07"
            # Mullvad
            "194.242.2.2"
            "2a07:e340::2"
          ];
          base_domain = "lion-zebra.ts.net";
        };
        derp = {
          server = {
            enable = true;
            region_id = 999;
            region_code = domain;
            region_name = domain + " DERP";
            stun_listen_addr = "0.0.0.0:3478";
            automatically_add_embedded_derp_region = true;
          };
          # urls = [ ];
        };
      };
    };

    headplane = {
      enable = true;
      agent.enable = false;
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
          cookie_secret = "xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX";
          cookie_secure = true;
        };
        headscale = {
          # url = "http://${domain}:8080";
          # url = "https://controlplane.${domain}";
          url = "http://127.0.0.1:8080";
            # A workaround generate a valid Headscale config accepted by Headplane when `config_strict == true`.
          # config_path = (pkgs.formats.yaml {}).generate "headscale.yml" (lib.recursiveUpdate config.services.headscale.settings {
          #   acme_email = "/dev/null";
          #   tls_cert_path = "/dev/null";
          #   tls_key_path = "/dev/null";
          #   policy.path = "/dev/null";
          #   oidc.client_secret_path = "/dev/null";
          # });
          config_strict = true;
        };
        integration.proc.enabled = true;
      };
    };

    syncthing = {
      enable = true;
      openDefaultPorts = false;
      # openDefaultPorts = true;
      # guiAddress = "0.0.0.0:8384";
      user = "root";
      # group = "root";
      settings = {
        devices.pilab.id = "4ZGXF3T-AU3D6ZJ-JO4UQYO-O6TD5VT-KXB5XAA-BFMWMI7-Y7BFEFK-TUAIEA3";
        folders.headscale = {
          enable = true;
          label = "Headscale Data";
          path = "/var/lib/headscale";
          devices = [
            "pilab"
          ];
          id = "u233w-44w2s";
        };
      };
    };

    # uptime-kuma = {
    #   enable = true;
    #   # appriseSupport = false;
    #   appriseSupport = true;
    #   settings = {
    #     # HOST = "0.0.0.0";
    #     HOST = "127.0.0.1";
    #     PORT = "3001";
    #     # FIXME: This results in a permission error during nixos-rebuild.
    #     # DATA_DIR = lib.mkForce "/root/uptime-kuma";
    #   };
    # };

    nginx = {
      enable = true;
      virtualHosts = {
        "jitsi.${domain}" = {
          # basicAuth = {
          #   jitsi = "notthepass";
          # };
          basicAuthFile = config.sops.secrets."jitsi.htpasswd".path;
          # basicAuthFile = ./jitsi.htpasswd;
        };
        "miniserve.${domain}" = {
          forceSSL = true;
          enableACME = true;
          # locations."/".root = pkgs.miniserve;
          locations."/".proxyPass = "http://100.64.0.5:7055";
        };
        # "puwush.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://100.64.0.7:5100";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        "immich.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            # proxyPass = "http://100.64.0.7:2283";
            proxyPass = "http://100.64.0.7:2283";
            # Need this enabled to avoid header request issues.
            recommendedProxySettings = true;
          };
        };
        "vaultwarden.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://100.64.0.7:9446";
            # Need this enabled to avoid header request issues.
            recommendedProxySettings = true;
            extraConfig = ''
<<<<<<< Updated upstream
              allow 120.138.111.213;
=======
              allow 43.243.83.222;
>>>>>>> Stashed changes
              deny all;
            '';
          };
        };
        "controlplane.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8080";
            proxyWebsockets = true;
            # Need this enabled to avoid header request issues.
            recommendedProxySettings = true;
          };
        };
        "headplane.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:3000";
            # Need this enabled to avoid header request issues.
            recommendedProxySettings = true;
          };
        };
        # "uptime-kuma.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://127.0.0.1:3001";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "prefect.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://100.117.162.60:4200";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
      };
      streamConfig = ''
        server {
          # listen 0.0.0.0:5220 udp reuseport;
          listen 0.0.0.0:5220;
          proxy_timeout 20s;
          proxy_pass 100.64.0.7:5220;
        }
      '';
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "clawsiecats@omg.lol";
    certs."syncplay.${domain}".webroot = "/var/lib/acme/acme-challenge";
  };

  networking.firewall = {
    allowedTCPPorts = [
      # NGINX and ACME
      80
      443

      # Bore tunnels
      7835
      4200

      # Bombsquad
      43210

      5220
    ];
    allowedUDPPorts = [
      # Bombsquad
      43210
    ];
    # extraCommands = ''
    #   # Commenting these out for now as these rules interfere with running
    #   # Bombsquad server natively on the machine.
    #   ${pkgs.iptables}/bin/iptables -A FORWARD -i %i -j ACCEPT
    #   # Reverse proxy a bombsquad server running behind a NAT via Tailscale.
    #   ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
    #   ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p udp --dport 43210 -j DNAT --to-destination 100.104.56.111:43210
    # '';
  };
}
