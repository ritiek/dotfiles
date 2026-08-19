{ ... }:
{
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      valid-lifetime = 86400;
      renew-timer = 43200;
      rebind-timer = 75600;

      interfaces-config = {
        # The only thing keeping kea off the WAN. Do not widen this.
        interfaces = [ "br-lan" ];

        # br-lan does not gain carrier until a LAN port or the AP comes up,
        # which happens after network-online.target fires. Without retries kea
        # opens zero sockets at startup and then stays permanently deaf.
        service-sockets-max-retries = 20;
        service-sockets-retry-wait-time = 5000;
      };

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
        lfc-interval = 3600;
      };

      subnet4 = [
        {
          # Mandatory and must be unique per subnet.
          id = 1;
          subnet = "192.168.3.0/24";
          interface = "br-lan";

          # switchboard itself is .1; everything above it is fair game. There is
          # no reason to hold back a .2-.99 "static block" here: kea honours
          # reservations that fall inside a pool (reservations-out-of-pool
          # defaults to false, so every allocation is checked against them), so
          # a pinned host gets its address whether or not the pool covers it.
          #
          # The only thing a reserved-and-excluded block would buy is somewhere
          # safe to put devices whose IP is hardcoded in firmware rather than
          # handed out by DHCP. There are none on this subnet; if that changes,
          # raise the pool floor rather than scattering statics through it.
          pools = [ { pool = "192.168.3.2 - 192.168.3.240"; } ];

          option-data = [
            # switchboard's br-lan address, see modules/router/lan.nix. These
            # two must be changed together with lanAddress there.
            { name = "routers"; data = "192.168.3.1"; }
            # Pi-hole runs on this box and owns port 53 directly.
            { name = "domain-name-servers"; data = "192.168.3.1"; }
            { name = "domain-name"; data = "pihole"; }
          ];

          # Everything else on this subnet is still dynamic. As devices migrate
          # off the ONT's 192.168.2.0/24, read /var/lib/kea/dhcp4.leases and add
          # entries in the same shape, remembering to add the matching
          # services/pihole.nix host line so the name resolves.
          #
          # NOTE: these NICs have no burned-in MAC. udev's default
          # MACAddressPolicy=persistent derives one from the machine-id and the
          # device path, so it is stable across reboots but will change if
          # either of those does. Re-check here if a pinned host ever silently
          # lands back in the dynamic range.
          reservations = [
            {
              hw-address = "a6:1b:64:13:ce:60";
              ip-address = "192.168.3.2";
              hostname = "alcove";
            }
          ];
        }
      ];

      loggers = [
        {
          name = "kea-dhcp4";
          severity = "INFO";
          output_options = [ { output = "stderr"; } ];
        }
      ];
    };
  };
}
