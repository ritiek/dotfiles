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

          # switchboard itself is .1; the rest of the subnet is free, since
          # nothing has ever been addressed on it before. Leaving .2-.99 out of
          # the pool for future static assignments.
          pools = [ { pool = "192.168.3.100 - 192.168.3.240"; } ];

          option-data = [
            # switchboard's br-lan address, see modules/router/lan.nix. These
            # two must be changed together with lanAddress there.
            { name = "routers"; data = "192.168.3.1"; }
            # Pi-hole runs on this box and owns port 53 directly.
            { name = "domain-name-servers"; data = "192.168.3.1"; }
            { name = "domain-name"; data = "pihole"; }
          ];

          # Intentionally empty for now.
          #
          # Nothing that has a *.pihole name in services/pihole.nix lives on
          # this subnet -- those are all still on the ONT's 192.168.2.0/24 --
          # so there is nothing to pin yet. As devices migrate here, read
          # /var/lib/kea/dhcp4.leases and add entries of the form:
          #   { hw-address = "aa:bb:cc:dd:ee:ff";
          #     ip-address = "192.168.3.8";
          #     hostname   = "some-host"; }
          # remembering to update the matching pihole.nix entry.
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
