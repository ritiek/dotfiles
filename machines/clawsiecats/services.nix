{ config, lib, pkgs, ... }:

let
  domain = "clawsiecats.omg.lol";
in
{
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
        "puwush.${domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://100.76.250.31:5100";
            # Need this enabled to avoid header request issues.
            recommendedProxySettings = true;
          };
        };
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

      # Bore tunnels
      # 7835

      # Bombsquad
      # 43210
    ];
    allowedUDPPorts = [
      # Bombsquad
      43210
    ];
    extraCommands = ''
      ${pkgs.iptables}/bin/iptables -A FORWARD -i %i -j ACCEPT
      # Reverse proxy a bombsquad server running behind a NAT via Tailscale.
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
      ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p udp --dport 43210 -j DNAT --to-destination 100.104.56.111:43210
    '';
  };
}
