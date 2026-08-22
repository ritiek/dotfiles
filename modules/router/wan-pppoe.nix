{ config, lib, ... }:
let
  # Physical WAN NIC. end1 is the dwmac-sun55i MAC (DWMAC4/5, real DMA
  # capability register, RX mitigation via HW watchdog timer). It gets the WAN
  # role because that is the interface taking the highest inbound packet rate,
  # and its interrupt coalescing is what relieves the CPU0 IRQ concentration
  # (both NICs are single-queue with every IRQ landing on CPU0).
  wanPhys = "end1";
  # Name of the interface pppd creates. Referenced by lan.nix (DHCPv6-PD
  # uplink) and nat-firewall.nix (NAT external interface).
  wanPpp = "ppp-wan";
in
{
  # See modules/router/options.nix. Swapping this module for wan-dhcp.nix is
  # the entire A -> B (and back) migration; lan.nix and nat-firewall.nix read
  # these and need no edits.
  router.wanInterface = wanPpp;
  router.ipv6PrefixDelegation = true;

  # Whole-file secret, matching this repo's convention (sops.templates is used
  # nowhere here). Contents are pppd option lines:
  #   user "..."
  #   password "..."
  sops.secrets."pppoe.secrets".restartUnits = [ "pppd-isp.service" ];

  services.pppd = {
    enable = true;
    peers.isp = {
      autostart = true;
      config = ''
        # NOTE: "pppoe.so", not "rp-pppoe.so". The plugin was renamed in
        # ppp 2.5.x (nixpkgs#251273); older guides still say rp-pppoe.so
        # and fail on current nixpkgs.
        plugin pppoe.so ${wanPhys}
        ifname ${wanPpp}

        # Credentials live in sops, not here: /etc/ppp/peers/isp is a
        # world-readable store path, and this repo is public. pppd's "file"
        # directive reads further options out of the named file, so the secret
        # holds the literal `user "..."` / `password "..."` lines.
        file ${config.sops.secrets."pppoe.secrets".path}

        # We authenticate to the ISP, not the other way round.
        noauth
        hide-password
        noipdefault
        defaultroute
        replacedefaultroute

        # IPv6CP. This only yields a link-local fe80::/64 on the ppp link --
        # the global prefix comes from DHCPv6-PD, driven by networkd below.
        #
        # Deliberately NOT setting "defaultroute6": pppd(8) warns it conflicts
        # with the kernel's own IPv6 route setup. The v6 default route must
        # come from the ISP's RA on the ppp link (IPv6AcceptRA below).
        +ipv6
        ipv6cp-accept-local

        # PPPoE adds 8 bytes (6 PPPoE + 2 PPP). See the MSS clamp in
        # nat-firewall.nix -- without it, large-MTU paths blackhole.
        mtu 1492
        mru 1492

        persist
        maxfail 0
        holdoff 5
        lcp-echo-interval 10
        lcp-echo-failure 5
        lcp-echo-adaptive
        noaccomp
        default-asyncmap
      '';
    };
  };

  systemd.services."pppd-isp" = {
    # The pppd module hardcodes Before=network.target (nixpkgs#489207). If the
    # WAN is down at boot, network.target stalls ~300s and everything ordered
    # after it hangs with it. This box must boot to a usable LAN regardless of
    # whether the ISP is answering.
    before = lib.mkForce [ ];

    # A networkd restart otherwise tears down the PPPoE session silently, with
    # pppd none the wiser. Tie their lifecycles together.
    after = [ "systemd-networkd.service" ];
    partOf = [ "systemd-networkd.service" ];
  };

  # MAC-clone experiment (matching the ONT WAN entry's distinct MAC ...D:AA,
  # separate from the chassis/LAN/Wireless MAC ...D:A8) was tried and reverted:
  # cloning it changed nothing (PADO still never arrived) and it turned out to
  # duplicate a MAC still live on the ONT's own WAN entry, which is itself a
  # confound. See CUTOVER.md for the fuller PADO-timeout investigation; this
  # box reverts to udev's default naming/MAC for end1.
  systemd.network.networks."20-${wanPhys}" = {
    # pppd needs the physical NIC up but with no L3 configuration of its own.
    matchConfig.Name = wanPhys;
    networkConfig.LinkLocalAddressing = "no";
    linkConfig = {
      ActivationPolicy = "always-up";
      RequiredForOnline = "no";
    };
  };

  systemd.network.networks."25-${wanPpp}" = {
    matchConfig.Name = wanPpp;

    networkConfig = {
      # pppd owns the IPv4 address and default route; networkd must not
      # clobber them when it takes over management of the interface.
      KeepConfiguration = true;

      DHCP = "ipv6";
      IPv6AcceptRA = true;
      IPv6SendRA = false;

      # Set per-link rather than relying on the global sysctl. networkd
      # manages net.{ipv4,ipv6}.conf.<iface>.forwarding itself, so leaving
      # these unset means the global value can be silently overridden on a
      # per-interface basis.
      IPv4Forwarding = true;
      IPv6Forwarding = true;
    };

    dhcpV6Config = {
      PrefixDelegationHint = "::/56";
      # The single most important setting here. Without it networkd waits for
      # an RA with the M/O flag set before soliciting, and plenty of ISPs
      # never set it -- DHCPv6 then simply never fires.
      WithoutRA = "solicit";
      # Most ISPs hand out IA_PD only, no IA_NA.
      UseAddress = false;
      UseDNS = false;
    };

    ipv6AcceptRAConfig = {
      UseDNS = false;
      UseMTU = false;
      DHCPv6Client = "always";
    };

    linkConfig.RequiredForOnline = "no";
  };
}
