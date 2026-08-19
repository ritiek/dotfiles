{ ... }:
let
  # Physical WAN NIC. end1 is the dwmac-sun55i MAC (DWMAC4/5, real DMA
  # capability register, RX mitigation via HW watchdog timer). It gets the WAN
  # role because that is the interface taking the highest inbound packet rate,
  # and its interrupt coalescing is what relieves the CPU0 IRQ concentration
  # (both NICs are single-queue with every IRQ landing on CPU0).
  wanPhys = "end1";
in
{
  # ---------------------------------------------------------------------
  # Variant A: the ONT (Genexis XC220-G3) is left alone and keeps routing
  # 192.168.2.0/24. switchboard takes an ordinary DHCP lease from it on end1
  # and NATs 192.168.3.0/24 behind that.
  #
  # This is deliberately double NAT. The tradeoff is that nothing currently on
  # the network has to move: every device stays on the ONT's segment, all the
  # 192.168.2.x entries in services/pihole.nix stay correct, and the ONT's web
  # UI stays reachable at 192.168.2.1 (switchboard itself can reach it directly
  # once it holds a lease on that segment).
  #
  # Variant B is modules/router/wan-pppoe.nix: flip the ONT to bridge mode and
  # swap this import for that one. Nothing else needs to change -- both set
  # router.wanInterface, which is all lan.nix and nat-firewall.nix consume.
  # ---------------------------------------------------------------------
  router.wanInterface = wanPhys;

  # A consumer ONT in router mode does not delegate a prefix, so the LAN is
  # IPv4-only for now. Flipping to PPPoE turns this back on.
  router.ipv6PrefixDelegation = false;

  systemd.network.networks."20-${wanPhys}" = {
    matchConfig.Name = wanPhys;

    networkConfig = {
      DHCP = "ipv4";

      # Nothing useful upstream on v6 while the ONT is routing, and accepting
      # its RAs would install a default route we do not want.
      IPv6AcceptRA = false;

      # networkd manages the per-link forwarding sysctls itself and will
      # happily override the global ones set in nat-firewall.nix.
      IPv4Forwarding = true;
      IPv6Forwarding = true;
    };

    dhcpV4Config = {
      # pihole-ftl on this box owns resolution. Taking the ONT's nameservers
      # would rewrite /etc/resolv.conf out from under it.
      UseDNS = false;
      UseDomains = false;
      UseNTP = false;
      # Lower than the LAN's implicit metric, and matches what the box used to
      # get from NetworkManager on this NIC.
      RouteMetric = 100;
    };

    linkConfig.RequiredForOnline = "routable";
  };
}
