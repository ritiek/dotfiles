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
          subnet = "192.168.2.0/24";
          interface = "br-lan";

          # Everything in pihole.nix's static hosts list for this subnet sits
          # at .4-.15, the ONT keeps .1 as a management address, and switchboard
          # itself is at .254, so the pool is clear of all of them.
          pools = [ { pool = "192.168.2.100 - 192.168.2.240"; } ];

          option-data = [
            # switchboard's br-lan address, see modules/router/lan.nix. Not .1,
            # which the ONT holds on to even in bridge mode.
            { name = "routers"; data = "192.168.2.254"; }
            # Pi-hole runs on this box and owns port 53 directly.
            { name = "domain-name-servers"; data = "192.168.2.254"; }
            { name = "domain-name"; data = "pihole"; }
          ];

          # Intentionally empty.
          #
          # Devices at 192.168.2.4/.5/.8/.9/.11/.13/.14/.15 have *.pihole names
          # pinned to those addresses in services/pihole.nix. If any of them
          # were getting those addresses from the modem's DHCP reservations
          # rather than static config on the device itself, they will land in
          # the pool above after cutover and their names will resolve to the
          # wrong host.
          #
          # These are not pre-populated because the live ARP snapshot is not
          # trustworthy enough to derive them from: .8 and .11 report the same
          # MAC (pilab answering ARP on both its wired and wireless
          # interfaces), and several of the listed hosts were not in the table
          # at all. Guessing here risks handing the wrong address to the wrong
          # device.
          #
          # After cutover, read /var/lib/kea/dhcp4.leases, match each device,
          # and add entries of the form:
          #   { hw-address = "aa:bb:cc:dd:ee:ff";
          #     ip-address = "192.168.2.8";
          #     hostname   = "pilab-ethernet"; }
          reservations = [ ];
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
