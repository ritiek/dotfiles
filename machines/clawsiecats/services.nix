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
          server.enable = true;
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
          # host = "127.0.0.1";
          host = "0.0.0.0";
          port = 3000;
          cookie_secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          cookie_secure = false;
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
        # oidc = {
        #   issuer = "https://oidc.example.com";
        #   client_id = "headplane";
        #   client_secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        #   disable_api_key_login = true;
        #   # Might needed when integrating with Authelia.
        #   token_endpoint_auth_method = "client_secret_basic";
        #   headscale_api_key = "xxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        #   redirect_uri = "https://oidc.example.com/admin/oidc/callback";
        # };
      };
    };

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
        # "miniserve.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   # locations."/".root = pkgs.miniserve;
        #   locations."/".proxyPass = "http://127.0.0.1:8081";
        # };
        # "puwush.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://100.76.250.31:5100";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "immich.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://100.76.250.31:2283";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
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

      # Headplane
      3000

      # Bore tunnels
      7835
      4200

      # Bombsquad
      43210
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
