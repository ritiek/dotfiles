# PS4 jailbreak exploit server (PSFree + Lapse via WebKitty).
#
# PS4 network settings (LAN cable, static):
#   IP 10.13.37.2, mask 255.255.255.0, gateway and DNS 10.13.37.1
#
# DNS blocks Sony update/telemetry domains, so auto-updates are blocked too.

{ pkgs, ... }:

let
  webkitty = pkgs.fetchFromGitHub {
    owner = "ArabPixel";
    repo = "WebKitty";
    rev = "b44d2a2ae56032578ea44c6e7d578d1ad6a555de";
    hash = "sha256-bexDCU5sn99MrsOUZqMrIoPKfQ59YOJZn07FJ/JVA+8=";
  };
  blocked = [
    "playstation.net" "playstation.com" "psndl.net" "sonyentertainmentnetwork.com"
    "playstation.sony.akadns.net" "ribob01.net" "akamai.net"
  ];
  # Subdomains of `blocked` that must still resolve (STUN/NAT, network test).
  allowed = [
    "stun.playstation.net" "ena.net.playstation.net" "post.net.playstation.net"
    "get.net.playstation.net" "gst.prod.dl.playstation.net"
  ];
in
{
  networking.interfaces.end0.ipv4.addresses = [{ address = "10.13.37.1"; prefixLength = 24; }];

  # Upstreams come from /etc/resolv.conf (re-read on change); '#' = those servers.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = "end0";
      except-interface = "lo";
      bind-dynamic = true; # start without end0, bind when it appears
      server = map (d: "/${d}/#") allowed;
      address = map (d: "/${d}/") blocked;
    };
  };

  # Listens on 0.0.0.0 so nginx starts without end0; firewall limits it to the PS4.
  services.nginx.virtualHosts."ps4-exploit" = {
    listen = [{ addr = "0.0.0.0"; port = 80; }];
    root = webkitty;
    locations."/" = {
      index = "index.html";
      tryFiles = "$uri $uri/ /index.html";
    };
    locations."~ \\.manifest$".extraConfig = ''
      default_type text/cache-manifest;
    '';
  };

  # PS4 reaches the internet through wlan0.
  networking.nat = {
    enable = true;
    internalInterfaces = [ "end0" ];
    externalInterface = "wlan0";
  };

  networking.firewall = {
    interfaces.end0 = {
      allowedTCPPorts = [ 53 80 ];
      allowedUDPPorts = [ 53 ];
    };
    # Force all PS4 DNS through dnsmasq (even hardcoded servers) and block DNS-over-TLS.
    extraCommands = ''
      iptables -t nat -A PREROUTING -i end0 -p udp --dport 53 -j REDIRECT
      iptables -t nat -A PREROUTING -i end0 -p tcp --dport 53 -j REDIRECT
      iptables -I FORWARD -i end0 -p tcp --dport 853 -j DROP
    '';
    extraStopCommands = ''
      iptables -t nat -D PREROUTING -i end0 -p udp --dport 53 -j REDIRECT 2>/dev/null || true
      iptables -t nat -D PREROUTING -i end0 -p tcp --dport 53 -j REDIRECT 2>/dev/null || true
      iptables -D FORWARD -i end0 -p tcp --dport 853 -j DROP 2>/dev/null || true
    '';
  };
}
