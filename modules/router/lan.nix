{ lib, ... }:
let
  # end0 is the dwmac-sun8i MAC (the weaker of the two: no DMA capability
  # register, chain-mode descriptors). It carries the LAN, where the packet
  # rate is lower than on the WAN.
  lanPhys = "end0";
  # Onboard AIC8800D80. Runs as an AP (see modules/wifi/hostapd_ap.nix) and is
  # bridged into the same L2 domain as the wired LAN.
  lanWlan = "wlan0";
  lanBridge = "br-lan";

  # The LAN keeps 192.168.2.0/24 so that every 192.168.2.x entry in the static
  # hosts list in machines/switchboard/services/pihole.nix stays valid.
  #
  # switchboard sits at .254 rather than the conventional .1 because the ONT
  # keeps 192.168.2.1 as a management address even in bridge mode. Both boxes
  # answering .1 was confirmed live (arp showed the ONT's 3c:52:a1:27:4d:a8
  # winning), so .1 is left to the ONT and stays reachable for its web UI.
  #
  # dhcp.nix hands this address out as both the router and the DNS server, so
  # the two must be changed together.
  lanAddress = "192.168.2.254";
  lanPrefix = 24;
in
{
  # NetworkManager and hostapd cannot share a radio, and NM's catch-all DHCP
  # would fight networkd over every interface on the box.
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;
  networking.useDHCP = false;

  # pihole-ftl owns port 53 directly. resolved's stub listener would collide
  # with it, and switchboard should resolve through its own Pi-hole anyway.
  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  systemd.network = {
    enable = true;
    # The WAN is legitimately absent until PPPoE dials, and the bridge only
    # gains carrier once a LAN port comes up. Blocking boot on "all links
    # online" would hang for two minutes every time.
    wait-online.anyInterface = true;

    netdevs."10-${lanBridge}".netdevConfig = {
      Kind = "bridge";
      Name = lanBridge;
    };

    # NOTE: .network attribute names must sort below the 99-* defaults NixOS
    # ships, because the attribute name becomes the filename verbatim
    # (systemd#34229). Keep every prefix here under 70.
    networks = {
      "30-${lanPhys}" = {
        matchConfig.Name = lanPhys;
        networkConfig = {
          Bridge = lanBridge;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "enslaved";
      };

      # Note there is no Bridge= here. hostapd enslaves wlan0 into br-lan
      # itself (settings.bridge in modules/wifi/hostapd_ap.nix) so that
      # networkd is not also claiming the interface while hostapd flips it
      # from station to AP mode. This .network exists only to stop networkd
      # applying anything else to it.
      "30-${lanWlan}" = {
        matchConfig.Name = lanWlan;
        networkConfig = {
          LinkLocalAddressing = "no";
          # wlan0 has no carrier until hostapd has the AP beaconing.
          ConfigureWithoutCarrier = true;
        };
        linkConfig.RequiredForOnline = "no";
      };

      "40-${lanBridge}" = {
        matchConfig.Name = lanBridge;
        address = [ "${lanAddress}/${toString lanPrefix}" ];

        networkConfig = {
          ConfigureWithoutCarrier = true;
          IPv6AcceptRA = false;
          # Carve a /64 out of the prefix delegated on the WAN and advertise
          # it. networkd is used rather than radvd/corerad specifically
          # because it re-announces automatically when the ISP rotates the
          # delegated prefix.
          DHCPPrefixDelegation = true;
          IPv6SendRA = true;

          # Explicit per-link, for the same reason as on ppp-wan: networkd
          # manages the per-interface forwarding sysctls itself.
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };

        dhcpPrefixDelegationConfig = {
          UplinkInterface = "ppp-wan";
          SubnetId = 1;
          Token = "static:::1";
          Announce = true;
        };

        ipv6SendRAConfig = {
          EmitDNS = true;
          DNS = "_link_local";
          Managed = false;
          OtherInformation = false;
        };

        linkConfig.RequiredForOnline = "no";
      };
    };
  };
}
