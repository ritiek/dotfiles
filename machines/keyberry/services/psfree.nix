# PS4 jailbreak exploit server (PSFree + Lapse via WebKitty).
#
# PS4 network settings (LAN cable, static):
#   IP Address:       10.13.37.2
#   Subnet Mask:      255.255.255.0
#   Default Gateway:  10.13.37.1
#   Primary DNS:      10.13.37.1
#   Secondary DNS:    10.13.37.1
#
# All DNS resolves to keyberry, so auto-updates are blocked too.

{ pkgs, lib, ... }:

let
  webkitty = pkgs.fetchFromGitHub {
    owner = "ArabPixel";
    repo = "WebKitty";
    rev = "b44d2a2ae56032578ea44c6e7d578d1ad6a555de";
    hash = "sha256-bexDCU5sn99MrsOUZqMrIoPKfQ59YOJZn07FJ/JVA+8=";
  };
in
{
  # Static IP on the ethernet interface facing the PS4.
  networking.interfaces.end0.ipv4.addresses = [{
    address = "10.13.37.1";
    prefixLength = 24;
  }];

  # DNS on the PS4 ethernet link: block Sony update/telemetry domains,
  # forward everything else to Tailscale MagicDNS.
  environment.etc."dnsmasq-ps4.conf".text = ''
    interface=end0
    bind-interfaces
    listen-address=10.13.37.1
    no-dhcp-interface=end0

    # Upstream: Tailscale MagicDNS
    no-resolv
    server=100.100.100.100

    # Block Sony update & telemetry domains (NXDOMAIN)
    address=/playstation.net/
    address=/playstation.com/
    address=/psndl.net/
    address=/sonyentertainmentnetwork.com/
    address=/playstation.sony.akadns.net/
    address=/ribob01.net/
    address=/akamai.net/

    # Exceptions: allow STUN/NAT traversal and network services
    server=/stun.playstation.net/100.100.100.100
    server=/ena.net.playstation.net/100.100.100.100
    server=/post.net.playstation.net/100.100.100.100
    server=/get.net.playstation.net/100.100.100.100
    server=/gst.prod.dl.playstation.net/100.100.100.100
  '';

  systemd.services.dnsmasq-ps4 = {
    description = "Captive DNS for PS4 on end0";
    after = [ "network.target" "sys-subsystem-net-devices-end0.device" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/dnsmasq-ps4.pid";
      ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --conf-file=/etc/dnsmasq-ps4.conf --pid-file=/run/dnsmasq-ps4.pid";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # HTTP: serve WebKitty (PSFree + GoldHEN) on port 80.
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

  # Firewall: allow DNS and HTTP from PS4, allow inbound to PS4 from
  # tailscale, block PS4 reaching the internet through keyberry.
  networking.firewall = {
    allowedTCPPorts = lib.mkAfter [ 80 ];
    allowedUDPPorts = [ 53 ];
    extraCommands = ''
      # Block PS4 from reaching the internet via wlan0
      iptables -I FORWARD -i end0 -o wlan0 -j DROP

      # Allow tailscale <-> PS4 (inbound remote play)
      iptables -I FORWARD -i tailscale0 -o end0 -j ACCEPT
      iptables -I FORWARD -i end0 -o tailscale0 -j ACCEPT
    '';
    extraStopCommands = ''
      iptables -D FORWARD -i end0 -o wlan0 -j DROP 2>/dev/null || true
      iptables -D FORWARD -i tailscale0 -o end0 -j ACCEPT 2>/dev/null || true
      iptables -D FORWARD -i end0 -o tailscale0 -j ACCEPT 2>/dev/null || true
    '';
  };
}
