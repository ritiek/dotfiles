{ config, ... }:
let
  # Physical NICs. These are what the flowtable has to name, regardless of
  # which WAN variant is in use.
  wanPhys = "end1";
  lanPhys = "end0";

  # Logical WAN: "ppp-wan" under PPPoE, or end1 itself when the WAN is a plain
  # DHCP client. Set by whichever modules/router/wan-*.nix is imported.
  wan = config.router.wanInterface;

  lanBridge = "br-lan";
in
{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.nftables.enable = true;

  # `networking.nftables.checkRuleset` validates the ruleset at build time by
  # running `nft --check` against LKL (a userspace kernel) inside the sandbox.
  # That sandbox has no end0/end1, and unlike iifname/oifname -- which are
  # strings matched per packet -- a flowtable's `devices` list is resolved to
  # real netdevs at ruleset-load time. So the check fails with
  # "Could not process rule: No such file or directory" even though the rule is
  # perfectly valid on the actual box.
  #
  # Rewrite the device list to `lo` for the check only. Everything else in the
  # flowtable, and the `flow add @ft` rule that depends on it, still gets
  # syntax-checked; only the interface names go unvalidated, and those are
  # verified at boot instead.
  networking.nftables.preCheckRuleset = ''
    sed -E 's/devices = \{[^}]*\}/devices = { lo }/' -i ruleset.conf
  '';

  networking.firewall = {
    enable = true;

    # Turns the forward chain's policy into drop, so anything not explicitly
    # permitted is not routed. The nat module below injects the one accept we
    # actually want (LAN -> WAN).
    filterForward = true;

    # Sane on a router where return paths are not always symmetric.
    checkReversePath = "loose";

    # Switchboard's console is a 115200 baud serial line with
    # consoleLogLevel=8. Logging every refused connection from a public IPv4
    # address would saturate it with internet background scanning.
    logRefusedConnections = false;
  };

  networking.nat = {
    enable = true;
    externalInterface = wan;
    internalInterfaces = [ lanBridge ];
    # No IPv6 NAT. Under PPPoE, DHCPv6-PD (see lan.nix) gives LAN clients real
    # globally routable addresses; behind the ONT there is no v6 on the LAN at
    # all, so there is nothing to translate either way.
    enableIPv6 = false;
  };

  # nftables resolves iifname/oifname per packet, so rules naming ppp-wan load
  # fine before pppd has dialled and survive re-dials. (iif/oif would bind to
  # an ifindex at ruleset load time and fail outright.)
  networking.nftables.tables.router = {
    family = "inet";
    content = ''
      # ---------------------------------------------------------------
      # WAN edge policy.
      #
      # Several services on this box open their ports globally
      # (pihole-ftl openFirewallDNS/Webserver, homepage, gatus, sshd).
      # That was harmless behind the modem's NAT; with a public IP on
      # the WAN it would expose an open recursive resolver -- a DNS
      # amplification vector -- plus two web UIs and sshd.
      #
      # While the ONT is still routing, the "WAN" is only its LAN
      # segment, so this also means switchboard is not reachable from
      # anything hanging off the ONT. That is intentional: the
      # management paths are the direct LAN link, Tailscale (outbound,
      # so unaffected) and the serial console.
      #
      # Rather than unpick openFirewall in five separate service files,
      # this chain sits at a lower priority than nixos-fw's input chain
      # and drops unsolicited inbound traffic on the WAN before that
      # chain ever runs. It can only ever be more restrictive than
      # nixos-fw, never less: an accept here just falls through to it.
      #
      # There is deliberately no port forwarding. Remote access is via
      # Tailscale and Netbird, both of which work through conntrack
      # (outbound-initiated, UDP hole punched) without inbound holes.
      # ---------------------------------------------------------------
      chain wan-input {
        type filter hook input priority filter - 10; policy accept;

        iifname != "${wan}" accept
        ct state { established, related } accept

        # ICMP must survive: PMTUD needs ICMPv4 frag-needed and ICMPv6
        # packet-too-big, and IPv6 additionally needs NDP and the RA that
        # carries our default route.
        meta l4proto { icmp, ipv6-icmp } accept

        # DHCP client replies. networkd does the initial handshake over
        # an AF_PACKET socket, which bypasses netfilter entirely, but
        # unicast renewals come back over UDP and would otherwise rely
        # solely on the conntrack entry surviving the lease time.
        udp dport 68 accept

        # DHCPv6 client replies from the ISP (prefix delegation).
        udp dport 546 accept

        counter drop
      }

      # ---------------------------------------------------------------
      # TCP MSS clamping. PPPoE costs 8 bytes, so the link MTU is 1492
      # while the LAN stays at 1500. Harmless when the WAN is a plain
      # 1500-MTU DHCP link -- "rt mtu" resolves to the real path MTU, so
      # the rule self-adjusts rather than needing to be conditional.
      #
      # This cannot live in networking.firewall.extraForwardRules: those
      # rules land in the forward-allow chain, which is only reached from
      # the conntrack vmap on new/untracked. The outbound SYN is new and
      # would be clamped, but the returning SYN+ACK is already
      # established and would never reach the chain. Both directions have
      # to be mangled, hence a dedicated chain at mangle priority.
      #
      # There is no NixOS option for MSS clamping.
      # ---------------------------------------------------------------
      chain mss-clamp {
        type filter hook forward priority mangle; policy accept;

        oifname "${wan}" tcp flags syn / syn,rst tcp option maxseg size set rt mtu
        iifname "${wan}" tcp flags syn / syn,rst tcp option maxseg size set rt mtu
      }

      # ---------------------------------------------------------------
      # Software flow offload.
      #
      # Not optional on this hardware. Both NICs are single-queue with
      # every interrupt pinned to CPU0, there is no cpufreq driver, and
      # PPPoE receive is serialised on one socket BH lock
      # (__sk_receive_skb -> ppp_input); the fix for that is net-next
      # only and is not in kernel 7.0. The flowtable hooks at ingress,
      # before pppoe_rcv(), so offloaded flows never touch that lock.
      #
      # Devices are the *physical* NICs, not ppp-wan: since 5.13 the
      # flowtable finds the real netdevice behind PPPoE and VLAN
      # interfaces and handles the L2 decapsulation itself.
      #
      # There is no hardware offload -- dwmac-sun8i and dwmac-sun55i
      # implement no setup_tc/TC_SETUP_FT -- so "flags offload" would
      # fail with EOPNOTSUPP.
      #
      # Tradeoff: nftables counters in the forward chain stop counting
      # offloaded packets, and anything relying on per-packet inspection
      # after ingress (DSCP marking, nfqueue, connlimit) will not see
      # them. Plain qdisc shaping still applies -- software offload
      # still goes through neigh_xmit().
      # ---------------------------------------------------------------
      flowtable ft {
        hook ingress priority filter
        devices = { ${wanPhys}, ${lanPhys} }
        counter
      }

      # Priority filter + 10 puts this *after* nixos-fw's forward chain,
      # so only traffic the firewall already permitted gets offloaded.
      # NB: cannot be named "offload" -- that is a reserved nftables keyword.
      chain flow-offload {
        type filter hook forward priority filter + 10; policy accept;

        ct state established,related flow add @ft
      }
    '';
  };
}
