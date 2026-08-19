{ lib, ... }:
{
  # Shared knobs so that swapping the WAN implementation is a one-line import
  # change in machines/switchboard/default.nix rather than an edit across
  # lan.nix and nat-firewall.nix.
  #
  # Exactly one of modules/router/wan-*.nix must be imported; each sets these.
  options.router = {
    wanInterface = lib.mkOption {
      type = lib.types.str;
      description = ''
        Interface that faces upstream. NAT masquerades out of it, the WAN edge
        drop chain filters inbound on it, and TCP MSS is clamped across it.

        This is the *logical* interface: "ppp-wan" for PPPoE, or the physical
        NIC when the WAN is a plain DHCP client. It is deliberately not the
        same thing as the physical device used by the flowtable, which always
        has to be the real NIC.
      '';
    };

    ipv6PrefixDelegation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether the upstream hands us a delegated IPv6 prefix (DHCPv6-PD).

        True on a real ISP link, false when sitting behind a consumer
        router/ONT that is still doing the routing, in which case the LAN is
        IPv4-only and there is no prefix to carve a /64 out of.
      '';
    };
  };
}
