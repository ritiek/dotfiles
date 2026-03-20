{ config, lib, pkgs, inputs, ... }:

let
  domain = "clawsiecats.lol";
in
{
  imports = [
    inputs.simple-nixos-mailserver.nixosModule
    ./headscale
  ];

  sops.secrets = {
    "syncthing.gui_password" = {};
    "jitsi.htpasswd" = {
      owner = "nginx";
    };
    "syncplay.password" = {};
    "mail.me" = {};
  };

  environment.persistence."/nix/persist/system" = {
    directories = [
      "/var/lib/acme"
      "/var/lib/jitsi-meet"
      "/var/lib/prosody"
      "/var/lib/netbird"
      "/var/lib/netbird-birdnet"
      "/var/lib/netbird-mgmt"
      # {
      #     directory = "/var/lib/prosody";
      #     user = config.ids.uids.prosody;
      #     group = config.ids.gids.prosody;
      #     mode = "u=rwx,g=rx,o=";
      # }
      "/var/lib/syncthing"
      "/var/lib/vaultwarden-exports"
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

  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8792"
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

    # syncplay = {
    #   enable = true;
    #   passwordFile = config.sops.secrets."syncplay.password".path;
    #   useACMEHost = "syncplay.${domain}";
    # };

    # netbird = {
    #   enable = true;
    #   # useRoutingFeatures = "both";
    #   server = {
    #     enable = true;
    #     domain = "netbird.${domain}";
    #     enableNginx = false;
    #     management = {
    #       enable = true;
    #       domain = "management.netbird.${domain}";
    #       turnDomain = lib.mkForce "coturn.netbird.${domain}";
    #       turnPort = lib.mkForce 3478;
    #       enableNginx = false;
    #       oidcConfigEndpoint = "";
    #       settings = {
    #         EmbeddedIdP = {
    #           Enabled = true;
    #           DataDir = "/var/lib/netbird/idp";
    #           Issuer = "https://management.netbird.${domain}/oauth2";
    #           DashboardRedirectURIs = [
    #             "https://dashboard.netbird.${domain}/#callback"
    #             "https://dashboard.netbird.${domain}/silent-callback"
    #           ];
    #         };
    #         # TODO: For testing only. Re-generate and replace this key through SOPS.
    #         EncryptionKey = "i3LIydgHhOqGaRXkusvnwwobWY8eMtMQqHtg/x61jy8=";
    #         # TODO: For testing only. Re-generate and replace this key through SOPS.
    #         DataStoreEncryptionKey = "Zuwae/z43fZyHLtugmeS2XdachsBBIKMuKrdevGKYTE=";
    #         Signal = {
    #           Proto = "https";
    #           URI = "signal.netbird.${domain}:443";
    #           Username = "";
    #           Password = null;
    #         };
    #         Stuns = [
    #           {
    #             Proto = "udp";
    #             URI = "stun:coturn.netbird.${domain}:3478";
    #             Username = "";
    #             Password = null;
    #           }
    #         ];
    #         TURNConfig = {
    #           CredentialsTTL = "12h";
    #           Secret = "not-secure-secret";
    #           TimeBasedCredentials = false;
    #           Turns = [
    #             {
    #               Proto = "udp";
    #               URI = "turn:coturn.netbird.${domain}:3478";
    #               Username = "netbird";
    #               Password = "netbird";
    #             }
    #           ];
    #         };
    #       };
    #     };
    #     signal = {
    #       enable = true;
    #       domain = "signal.netbird.${domain}";
    #       enableNginx = false;
    #     };
    #     dashboard = {
    #       enable = false;  # We're serving static files manually
    #       domain = "dashboard.netbird.${domain}";
    #       enableNginx = false;
    #       settings = {
    #         AUTH_AUTHORITY = "https://management.netbird.${domain}/oauth2";
    #         AUTH_CLIENT_ID = "netbird-dashboard";
    #         AUTH_AUDIENCE = "https://management.netbird.${domain}/oauth2";
    #         USE_AUTH0 = false;
    #       };
    #     };
    #     coturn = {
    #       enable = true;
    #       domain = "coturn.netbird.${domain}";
    #       useAcmeCertificates = true;
    #       password = "netbird";
    #     };
    #   };
    # };

    syncthing = {
      enable = true;
      openDefaultPorts = false;
      # openDefaultPorts = true;
      guiAddress = "127.0.0.1:8384";
      # guiAddress = "0.0.0.0:8384";
      user = "root";
      # group = "root";
      settings = {
        devices = {
          pilab = {
            id = "4ZGXF3T-AU3D6ZJ-JO4UQYO-O6TD5VT-KXB5XAA-BFMWMI7-Y7BFEFK-TUAIEA3";
            autoAcceptFolders = true;
          };
          # redmi-note-11 = {
          #   id = "DKK6FNQ-JCCB3XM-SD7G6RF-S22N4HW-OVRC35N-VICROEH-CMS6JCF-DY72SAJ";
          #   autoAcceptFolders = true;
          # };
          # keyberry = {
          #   id = "BK2AFLY-Z672PPH-HMKYCFW-HD6OQOZ-4TZWZDC-2IPGC6T-3Q6BCRZ-YL4KVQM";
          #   autoAcceptFolders = true;
          # };
        };
        folders = {
          # headscale = {
          #   enable = true;
          #   label = "Headscale Data";
          #   path = "/var/lib/headscale";
          #   devices = [
          #     "pilab"
          #   ];
          #   id = "u233w-44w2s";
          # };
          vaultwarden-exports = {
            enable = true;
            label = "Vaultwarden Exports";
            path = "/var/lib/vaultwarden-exports";
            devices = [
              "pilab"
              # "redmi-note-11"
              # "keyberry"
            ];
            id = "epeoa-hjrkf";
            type = "receiveonly";
          };
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
      clientMaxBodySize = "2g";
      # Use systemd-resolved's stub as the nginx resolver so that .ts.net
      # upstream hostnames (resolved via Tailscale MagicDNS) are looked up at
      # request time rather than at nginx startup. Combined with variable-based
      # proxy_pass below, this prevents nginx from failing to start on boot
      # before Tailscale is connected. 127.0.0.53 is always available since
      # systemd-resolved starts independently of Tailscale.
      resolver.addresses = [ "127.0.0.53" ];
      eventsConfig = ''
        worker_connections 10240;
      '';
      commonHttpConfig = ''
        # Connection pooling for parallel uploads (global HTTP context)
        keepalive_timeout 600s;
      '';
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
        #   locations."/".proxyPass = "http://100.64.0.5:7055";
        # };
        # "puwush.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:5100";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        "immich.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            recommendedProxySettings = true;
            extraConfig = ''
              set $upstream "pilab.lion-zebra.ts.net:2283";
              proxy_pass http://$upstream;
            '';
          };
        };
        "vaultwarden.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            recommendedProxySettings = true;
            # extraConfig = ''
            #   allow 127.0.0.1;
            #   deny all;
            # '';
            extraConfig = ''
              set $upstream "pilab.lion-zebra.ts.net:9446";
              proxy_pass http://$upstream;
            '';
          };
        };
        "controlplane.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8088";
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

        # # Netbird dashboard - serve static files with injected config
        # "dashboard.netbird.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   root = pkgs.runCommand "netbird-dashboard-configured" {
        #     nativeBuildInputs = [ pkgs.gettext ];
        #     USE_AUTH0 = "false";
        #     AUTH_AUTHORITY = "https://management.netbird.${domain}/oauth2";
        #     AUTH_CLIENT_ID = "netbird-dashboard";
        #     AUTH_CLIENT_SECRET = "";
        #     AUTH_SUPPORTED_SCOPES = "openid profile email offline_access";
        #     AUTH_AUDIENCE = "https://management.netbird.${domain}/oauth2";
        #     NETBIRD_MGMT_API_ENDPOINT = "https://netbird.${domain}";
        #     NETBIRD_MGMT_GRPC_API_ENDPOINT = "https://netbird.${domain}";
        #     AUTH_REDIRECT_URI = "";
        #     AUTH_SILENT_REDIRECT_URI = "";
        #     NETBIRD_TOKEN_SOURCE = "accessToken";
        #     NETBIRD_DRAG_QUERY_PARAMS = "";
        #     NETBIRD_HOTJAR_TRACK_ID = "";
        #     NETBIRD_GOOGLE_ANALYTICS_ID = "";
        #     NETBIRD_GOOGLE_TAG_MANAGER_ID = "";
        #     NETBIRD_WASM_PATH = "";
        #   } ''
        #     cp -r ${pkgs.netbird-dashboard} $out
        #     chmod -R +w $out
        #     # Replace only our specific $VARIABLE placeholders, not arbitrary $ in JS
        #     for f in $(find $out -type f \( -name "*.js" -o -name "*.html" \)); do
        #       envsubst '$USE_AUTH0 $AUTH_AUTHORITY $AUTH_CLIENT_ID $AUTH_CLIENT_SECRET $AUTH_SUPPORTED_SCOPES $AUTH_AUDIENCE $NETBIRD_MGMT_API_ENDPOINT $NETBIRD_MGMT_GRPC_API_ENDPOINT $AUTH_REDIRECT_URI $AUTH_SILENT_REDIRECT_URI $NETBIRD_TOKEN_SOURCE $NETBIRD_DRAG_QUERY_PARAMS $NETBIRD_HOTJAR_TRACK_ID $NETBIRD_GOOGLE_ANALYTICS_ID $NETBIRD_GOOGLE_TAG_MANAGER_ID $NETBIRD_WASM_PATH' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        #     done
        #   '';
        #   extraConfig = ''
        #     # Strip trailing slash internally, then try .html variant for Next.js static export
        #     location ~ ^(.+)/$ {
        #       try_files $uri $1.html /index.html;
        #     }
        #     location / {
        #       try_files $uri $uri.html /index.html;
        #     }
        #   '';
        # };
        # # Netbird management API
        # "management.netbird.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   http2 = true;
        #   extraConfig = ''
        #     location /signalexchange.SignalExchange {
        #       grpc_pass grpc://127.0.0.1:10000;
        #       grpc_set_header Host $host;
        #       grpc_set_header X-Real-IP $remote_addr;
        #       grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       grpc_read_timeout 3600s;
        #       grpc_send_timeout 3600s;
        #     }
        #     location / {
        #       grpc_pass grpc://127.0.0.1:33073;
        #       grpc_set_header Host $host;
        #       grpc_set_header X-Real-IP $remote_addr;
        #       grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       grpc_read_timeout 3600s;
        #       grpc_send_timeout 3600s;
        #     }
        #     location /api {
        #       proxy_pass http://127.0.0.1:8011;
        #       proxy_set_header Host $host;
        #       proxy_set_header X-Real-IP $remote_addr;
        #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       proxy_set_header X-Forwarded-Proto $scheme;
        #     }
        #     location /oauth2 {
        #       proxy_pass http://127.0.0.1:8011;
        #       proxy_set_header Host $host;
        #       proxy_set_header X-Real-IP $remote_addr;
        #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       proxy_set_header X-Forwarded-Proto $scheme;
        #     }
        #   '';
        # };
        # # Netbird API / management gRPC endpoint
        # "netbird.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   http2 = true;
        #   extraConfig = ''
        #     location /signalexchange.SignalExchange {
        #       grpc_pass grpc://127.0.0.1:10000;
        #       grpc_set_header Host $host;
        #       grpc_set_header X-Real-IP $remote_addr;
        #       grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       grpc_read_timeout 3600s;
        #       grpc_send_timeout 3600s;
        #     }
        #     location / {
        #       grpc_pass grpc://127.0.0.1:33073;
        #       grpc_set_header Host $host;
        #       grpc_set_header X-Real-IP $remote_addr;
        #       grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       grpc_read_timeout 3600s;
        #       grpc_send_timeout 3600s;
        #     }
        #     location /api {
        #       proxy_pass http://127.0.0.1:8011;
        #       proxy_set_header Host $host;
        #       proxy_set_header X-Real-IP $remote_addr;
        #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       proxy_set_header X-Forwarded-Proto $scheme;
        #     }
        #   '';
        # };
        # # Netbird signal server
        # "signal.netbird.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   http2 = true;
        #   extraConfig = ''
        #     location / {
        #       grpc_pass grpc://127.0.0.1:10000;
        #       grpc_set_header Host $host;
        #       grpc_set_header X-Real-IP $remote_addr;
        #       grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #       grpc_read_timeout 3600s;
        #       grpc_send_timeout 3600s;
        #     }
        #   '';
        # };

        # "nitter.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:5095";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        "attic.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            extraConfig = ''
              set $upstream "pilab.lion-zebra.ts.net:7080";
              proxy_pass http://$upstream;
              # Critical for large file uploads - disable buffering
              proxy_request_buffering off;
              proxy_buffering off;
              proxy_max_temp_file_size 0;

              # Timeouts for large binary cache uploads (10 minutes)
              proxy_read_timeout 600s;
              proxy_send_timeout 600s;
              proxy_connect_timeout 600s;

              # Increase body size limit for large NAR files
              client_max_body_size 2g;

              # Use HTTP/1.1 for better connection handling
              proxy_http_version 1.1;

              # Preserve headers needed by attic
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Connection "";
            '';
          };
        };
        # "ollama.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:3020";
        #     proxyWebsockets = true;
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "ha.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:8123";
        #     proxyWebsockets = true;
        #     recommendedProxySettings = true;
        #   };
        # };
        # "paperless.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:8010";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "n8n.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:5678";
        #     proxyWebsockets = true;
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "git.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:3033";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "filebrowser.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:8188";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "habitica.${domain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:3000";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
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
        resolver 127.0.0.53;
        server {
          listen 0.0.0.0:5219;
          proxy_timeout 20s;
          set $upstream "pilab.lion-zebra.ts.net:5219";
          proxy_pass $upstream;
        }
        server {
          listen 0.0.0.0:5220;
          proxy_timeout 20s;
          set $upstream "pilab.lion-zebra.ts.net:5220";
          proxy_pass $upstream;
        }
      '';
    };
  };

  mailserver = {
    enable = false;
    stateVersion = 3;
    fqdn = "mail.clawsiecats.lol";
    domains = [ "clawsiecats.lol" ];

    loginAccounts = {
      "me@clawsiecats.lol" = {
        hashedPasswordFile = config.sops.secrets."mail.me".path;
        # aliases = [ "" ];
      };
    };

    # certificateScheme = "acme-nginx";
  };
  
  security.acme = {
    acceptTerms = true;
    defaults.email = "ritiekmalhotra123@gmail.com";
    certs."syncplay.${domain}".webroot = "/var/lib/acme/acme-challenge";
    certs."coturn.netbird.${domain}".webroot = "/var/lib/acme/acme-challenge";
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

      5219
      5220

      # Coturn TURN/STUN
      3478
      3479
      5349
      5350
    ];
    allowedUDPPorts = [
      # Bombsquad
      43210

      # DERP STUN
      3478
      41641

      # Coturn TURN/STUN
      3479
      5349
      5350
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
