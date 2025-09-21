{ config, pkgs, lib, ... }:

{
  # Simple hostapd configuration for wlu2
  services.hostapd = {
    enable = true;
    radios = {
      wlu2 = {
        band = "2g";
        channel = 1;
        networks = {
          wlu2 = {
            ssid = "PiLab-Hotspot";
            authentication = {
              mode = "none";
            };
          };
        };
      };
    };
  };

  # Basic DHCP with dnsmasq
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "wlu2";
      bind-interfaces = true;
      dhcp-range = "192.168.4.10,192.168.4.100,24h";
      dhcp-option = [
        "option:router,192.168.4.1"
        "option:dns-server,8.8.8.8,1.1.1.1"
      ];
      server = [
        "8.8.8.8"
        "1.1.1.1"
      ];
      no-resolv = true;
    };
  };

  # Configure wlu2 interface
  networking.interfaces.wlu2 = {
    ipv4.addresses = [
      { address = "192.168.4.1"; prefixLength = 24; }
    ];
  };

  # Enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # NAT configuration
  networking.nat = {
    enable = true;
    externalInterface = "end0";
    internalInterfaces = [ "wlu2" ];
  };
}