{ config, lib, pkgs, inputs, ... }:

let
  primaryDomain = "clawsiecats.lol";
  domains = [ primaryDomain "clawsiecats.omg.lol" ];

  # Hardcoded prompt sent to hermes on a CI build failure. Edit here (not in
  # .github/workflows) to change what hermes is asked to do.
  matrixNotifyPrompt = "build failed. Please analyze the build log in the thread below, explain why it failed, and suggest possible solutions. Do NOT attempt to fix anything.";
  hermesUserId = "@hermes:pilab.lion-zebra.ts.net";

  # Receives a typed JSON payload from GitHub Actions (NOT a raw Matrix
  # message). Expected fields:
  #   { "job": "mishy", "run_url": "https://...", "pr_url": "https://..."|"", "log": "..." }
  # clawsiecats builds the full Matrix message (hardcoded prompt + @hermes
  # mention + HTML formatting) and sends the build log as a threaded reply.
  matrixNotifyScript = pkgs.writeShellScript "matrix-notify-script" ''
    set -euo pipefail
    HOMESERVER="http://pilab.lion-zebra.ts.net:6168"
    USERNAME="github-actions"
    PASSWORD="$(cat /run/secrets/github_actions_matrix_user.password)"
    ROOM_ID="!hbc1delAaoyVn6To30BJ8gWvbkVUkR-P3r4ZJTlJT04"
    PROMPT="${matrixNotifyPrompt}"
    HERMES="${hermesUserId}"
    PAYLOAD="$1"

    JQ="${pkgs.jq}/bin/jq"
    CURL="${pkgs.curl}/bin/curl"
    DATE="${pkgs.coreutils}/bin/date"

    JOB="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.job // "unknown"')"
    RUN_URL="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.run_url // ""')"
    PR_URL="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.pr_url // ""')"
    LOG="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.log // "(no build log available)"')"

    # Plain-text and HTML bodies for the prompt message.
    PLAIN="$JOB $PROMPT"$'\n'"Run: $RUN_URL"
    HTML="<a href=\"https://matrix.to/#/$HERMES\">hermes</a>: $JOB $PROMPT<br>Run: <a href=\"$RUN_URL\">$RUN_URL</a>"
    if [ -n "$PR_URL" ]; then
      PLAIN="$PLAIN"$'\n'"PR: $PR_URL"
      HTML="$HTML<br>PR: <a href=\"$PR_URL\">$PR_URL</a>"
    fi

    MSG_JSON="$("$JQ" -n --arg p "$PLAIN" --arg h "$HTML" --arg u "$HERMES" \
      '{"msgtype":"m.text","format":"org.matrix.custom.html","body":$p,"formatted_body":$h,"m.mentions":{"user_ids":[$u]}}')"

    TOKEN="$("$CURL" -sf -X POST "$HOMESERVER/_matrix/client/v3/login" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"m.login.password\",\"identifier\":{\"type\":\"m.id.user\",\"user\":\"$USERNAME\"},\"password\":\"$PASSWORD\"}" \
      | "$JQ" -r '.access_token')"

    # First message: the prompt + mention. Capture its event_id for threading.
    TXN1="$("$DATE" +%s%N)"
    RESP="$("$CURL" -sf -X PUT \
      "$HOMESERVER/_matrix/client/v3/rooms/$ROOM_ID/send/m.room.message/$TXN1" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary "$MSG_JSON")"
    EVENT_ID="$(printf '%s' "$RESP" | "$JQ" -r '.event_id')"

    # Second message: the build log, as a threaded reply to the prompt.
    LOG_JSON="$("$JQ" -n --arg log "$LOG" --arg eid "$EVENT_ID" \
      '{"msgtype":"m.text","body":$log,"m.relates_to":{"rel_type":"m.thread","event_id":$eid,"is_falling_back":true,"m.in_reply_to":{"event_id":$eid}}}')"
    TXN2="$((TXN1 + 1))"
    "$CURL" -sf -X PUT \
      "$HOMESERVER/_matrix/client/v3/rooms/$ROOM_ID/send/m.room.message/$TXN2" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary "$LOG_JSON"

    "$CURL" -sf -X POST "$HOMESERVER/_matrix/client/v3/logout" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{}" >/dev/null 2>&1 || true
  '';

  mkVhosts = domain: {
    "jitsi.${domain}" = {
      basicAuthFile = config.sops.secrets."jitsi.htpasswd".path;
    };
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
        extraConfig = ''
          set $upstream "pilab.lion-zebra.ts.net:9446";
          proxy_pass http://$upstream;
        '';
      };
    };
    "calibre.${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        recommendedProxySettings = true;
        extraConfig = ''
          set $upstream "pilab.lion-zebra.ts.net:8083";
          proxy_pass http://$upstream;
          proxy_buffer_size   1024k;
          proxy_buffers       4 512k;
          proxy_busy_buffers_size 1024k;
        '';
      };
    };
    "controlplane.${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8088";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };
    "headplane.${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        recommendedProxySettings = true;
      };
    };
    "search.${domain}" = {
      forceSSL = true;
      enableACME = true;
      basicAuthFile = config.sops.secrets."searx.htpasswd".path;
      locations."/" = {
        recommendedProxySettings = true;
        extraConfig = ''
          set $upstream "pilab.lion-zebra.ts.net:6040";
          proxy_pass http://$upstream;
          proxy_read_timeout 120s;
          proxy_connect_timeout 120s;
        '';
      };
    };
    "attic.${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        extraConfig = ''
          set $upstream "pilab.lion-zebra.ts.net:7080";
          proxy_pass http://$upstream;
          proxy_request_buffering off;
          proxy_max_temp_file_size 0;

          # Timeouts for large binary cache uploads (10 minutes)
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          proxy_connect_timeout 600s;

          # Increase body size limit for large NAR files
          client_max_body_size 2g;

          # Use HTTP/1.1 for better connection handling
          proxy_http_version 1.1;

          # Limit download bandwidth to 4 MB/s
          limit_rate 4m;

          # Preserve headers needed by attic
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Connection "";
        '';
      };
    };
    "readeck.${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        recommendedProxySettings = true;
        extraConfig = ''
          set $upstream "pilab.lion-zebra.ts.net:2399";
          proxy_pass http://$upstream;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffer_size   1024k;
          proxy_buffers       4 512k;
          proxy_busy_buffers_size 1024k;
        '';
      };
    };
    "webhook.${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."~ ^/matrix/github-actions/new/" = {
        extraConfig = ''
          rewrite ^(.*)$ /hooks/matrix-notify break;
          proxy_pass http://127.0.0.1:9001;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };
    };
  };
  in
{
  imports = [
    inputs.simple-nixos-mailserver.nixosModules.default
    ./headscale
  ];

  sops.secrets = {
    "syncthing.gui_password" = {};
    "jitsi.htpasswd" = {
      owner = "nginx";
    };
    "syncplay.password" = {};
    "mail.me" = {};
    "searx.htpasswd" = {
      owner = "nginx";
    };
    "webhook_matrix.auth" = {};
    "github_actions_matrix_user.password" = {};
  };

  sops.templates."matrix-notify-hooks" = {
    content = ''
      [
        {
          "id": "matrix-notify",
          "execute-command": "${matrixNotifyScript}",
          "command-working-directory": "/tmp",
          "http-methods": ["POST"],
          "pass-arguments-to-command": [{"source": "entire-payload", "name": "payload"}],
          "include-command-output-in-response": true,
          "trigger-rule": {
            "match": {
              "type": "value",
              "value": "Bearer ${config.sops.placeholder."webhook_matrix.auth"}",
              "parameter": {
                "source": "header",
                "name": "Authorization"
              }
            }
          }
        }
      ]
    '';
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
      hostName = "jitsi.${primaryDomain}";
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
    #   useACMEHost = "syncplay.${primaryDomain}";
    # };

    # netbird = {
    #   enable = true;
    #   # useRoutingFeatures = "both";
    #   server = {
    #     enable = true;
    #     domain = "netbird.${primaryDomain}";
    #     enableNginx = false;
    #     management = {
    #       enable = true;
    #       domain = "management.netbird.${primaryDomain}";
    #       turnDomain = lib.mkForce "coturn.netbird.${primaryDomain}";
    #       turnPort = lib.mkForce 3478;
    #       enableNginx = false;
    #       oidcConfigEndpoint = "";
    #       settings = {
    #         EmbeddedIdP = {
    #           Enabled = true;
    #           DataDir = "/var/lib/netbird/idp";
    #           Issuer = "https://management.netbird.${primaryDomain}/oauth2";
    #           DashboardRedirectURIs = [
    #             "https://dashboard.netbird.${primaryDomain}/#callback"
    #             "https://dashboard.netbird.${primaryDomain}/silent-callback"
    #           ];
    #         };
    #         # TODO: For testing only. Re-generate and replace this key through SOPS.
    #         EncryptionKey = "i3LIydgHhOqGaRXkusvnwwobWY8eMtMQqHtg/x61jy8=";
    #         # TODO: For testing only. Re-generate and replace this key through SOPS.
    #         DataStoreEncryptionKey = "Zuwae/z43fZyHLtugmeS2XdachsBBIKMuKrdevGKYTE=";
    #         Signal = {
    #           Proto = "https";
    #           URI = "signal.netbird.${primaryDomain}:443";
    #           Username = "";
    #           Password = null;
    #         };
    #         Stuns = [
    #           {
    #             Proto = "udp";
    #             URI = "stun:coturn.netbird.${primaryDomain}:3478";
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
    #               URI = "turn:coturn.netbird.${primaryDomain}:3478";
    #               Username = "netbird";
    #               Password = "netbird";
    #             }
    #           ];
    #         };
    #       };
    #     };
    #     signal = {
    #       enable = true;
    #       domain = "signal.netbird.${primaryDomain}";
    #       enableNginx = false;
    #     };
    #     dashboard = {
    #       enable = false;  # We're serving static files manually
    #       domain = "dashboard.netbird.${primaryDomain}";
    #       enableNginx = false;
    #       settings = {
    #         AUTH_AUTHORITY = "https://management.netbird.${primaryDomain}/oauth2";
    #         AUTH_CLIENT_ID = "netbird-dashboard";
    #         AUTH_AUDIENCE = "https://management.netbird.${primaryDomain}/oauth2";
    #         USE_AUTH0 = false;
    #       };
    #     };
    #     coturn = {
    #       enable = true;
    #       domain = "coturn.netbird.${primaryDomain}";
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
      # gixy cannot access sops runtime secrets during nix build phase
      validateConfigFile = false;
      resolver.addresses = [ "127.0.0.53" ];
      eventsConfig = ''
        worker_connections 10240;
      '';
      commonHttpConfig = ''
        # Connection pooling for parallel uploads (global HTTP context)
        keepalive_timeout 600s;
      '';
      virtualHosts = lib.mkMerge (map mkVhosts domains) // {
        # "miniserve.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   # locations."/".root = pkgs.miniserve;
        #   locations."/".proxyPass = "http://100.64.0.5:7055";
        # };
        # "puwush.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:5100";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "trmnl.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #     extraConfig = ''
        #       set $upstream "pilab.lion-zebra.ts.net:8093";
        #       proxy_pass http://$upstream;
        #     '';
        #   };
        # };

        # # Netbird dashboard - serve static files with injected config
        # "dashboard.netbird.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   root = pkgs.runCommand "netbird-dashboard-configured" {
        #     nativeBuildInputs = [ pkgs.gettext ];
        #     USE_AUTH0 = "false";
        #     AUTH_AUTHORITY = "https://management.netbird.${primaryDomain}/oauth2";
        #     AUTH_CLIENT_ID = "netbird-dashboard";
        #     AUTH_CLIENT_SECRET = "";
        #     AUTH_SUPPORTED_SCOPES = "openid profile email offline_access";
        #     AUTH_AUDIENCE = "https://management.netbird.${primaryDomain}/oauth2";
        #     NETBIRD_MGMT_API_ENDPOINT = "https://netbird.${primaryDomain}";
        #     NETBIRD_MGMT_GRPC_API_ENDPOINT = "https://netbird.${primaryDomain}";
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
        # "management.netbird.${primaryDomain}" = {
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
        # "netbird.${primaryDomain}" = {
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
        # "signal.netbird.${primaryDomain}" = {
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

        # "nitter.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:5095";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "ollama.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:3020";
        #     proxyWebsockets = true;
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "ha.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:8123";
        #     proxyWebsockets = true;
        #     recommendedProxySettings = true;
        #   };
        # };
        # "paperless.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:8010";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "n8n.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:5678";
        #     proxyWebsockets = true;
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "git.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:3033";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "filebrowser.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:8188";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "habitica.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://pilab.lion-zebra.ts.net:3000";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "uptime-kuma.${primaryDomain}" = {
        #   forceSSL = true;
        #   enableACME = true;
        #   locations."/" = {
        #     proxyPass = "http://127.0.0.1:3001";
        #     # Need this enabled to avoid header request issues.
        #     recommendedProxySettings = true;
        #   };
        # };
        # "prefect.${primaryDomain}" = {
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
        server {
          listen 0.0.0.0:8776;
          proxy_timeout 600s;
          set $upstream "pilab.lion-zebra.ts.net:8776";
          proxy_pass $upstream;
        }
      '';
    };
  };

  systemd.services.matrix-notify-webhook = {
    description = "Matrix notification webhook";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "sops-nix.service" ];
    # The hooks file path is a stable sops-template path, so the unit definition
    # never changes across rebuilds even when the script content does. webhook
    # only reads its hooks (and the baked execute-command path) at startup, so we
    # must force a restart whenever the script or hooks template content changes.
    restartTriggers = [
      matrixNotifyScript
      config.sops.templates."matrix-notify-hooks".content
    ];
    serviceConfig = {
      ExecStart =
        let hooksFile = config.sops.templates."matrix-notify-hooks".path;
        in "${pkgs.webhook}/bin/webhook -hooks ${hooksFile} -ip 127.0.0.1 -port 9001";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  mailserver = {
    enable = false;
    stateVersion = 3;
    fqdn = "mail.${primaryDomain}";
    domains = [ primaryDomain ];

    accounts = {
      "me@${primaryDomain}" = {
        hashedPasswordFile = config.sops.secrets."mail.me".path;
        # aliases = [ "" ];
      };
    };

    # certificateScheme = "acme-nginx";
  };
  
  security.acme = {
    acceptTerms = true;
    defaults.email = "ritiekmalhotra123@gmail.com";
    certs."syncplay.${primaryDomain}".webroot = "/var/lib/acme/acme-challenge";
    certs."coturn.netbird.${primaryDomain}".webroot = "/var/lib/acme/acme-challenge";
  };

  networking.firewall = {
    allowedTCPPorts = [
      # 3proxy HTTP proxy
      8090

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

      8776  # Radicle

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
