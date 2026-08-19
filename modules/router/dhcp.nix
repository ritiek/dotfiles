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
          #
          # The addresses below keep the last octet each device had on the
          # ONT's 192.168.2.0/24, so services/pihole.nix reads as a
          # straight s/2\./3./ and nothing has to be re-learned.
          reservations = [
            {
              hw-address = "a6:1b:64:13:ce:60";
              ip-address = "192.168.3.2";
              hostname = "alcove";
            }
            # pilab. It answered on both .8 and .16 of the ONT's segment from
            # this single MAC, so it can only hold one reservation -- the
            # pilab-wlan name is dropped in services/pihole.nix accordingly.
            {
              hw-address = "d8:3a:dd:bb:d3:6e";
              ip-address = "192.168.3.8";
              hostname = "pilab";
            }
            {
              hw-address = "42:c5:88:d0:96:68";
              ip-address = "192.168.3.9";
              hostname = "ritiek-edra-m2";
            }
            # alcove's wlan0. Only meaningful while alcove still associates
            # with the ONT's radios; harmless once it is wired-only.
            {
              hw-address = "9c:04:b6:9d:41:bd";
              ip-address = "192.168.3.12";
              hostname = "alcove-wlan";
            }
            {
              hw-address = "c8:93:46:8c:ff:f7";
              ip-address = "192.168.3.13";
              hostname = "phillips-air-purifier";
            }
            {
              hw-address = "6c:94:66:1e:6f:81";
              ip-address = "192.168.3.14";
              hostname = "robotic-arm-esp32";
            }
            {
              hw-address = "c4:82:e1:c7:75:0e";
              ip-address = "192.168.3.4";
              hostname = "mumbai-zebronics-switch";
            }
            {
              hw-address = "a0:24:42:0b:21:e2";
              ip-address = "192.168.3.5";
              hostname = "mumbai-halox-switch";
            }
            # Five more hosts were live on the ONT's segment but are
            # unidentified and unreferenced by any config, so they are left
            # dynamic: ac:27:6e:a8:4d:20 (had .2, serves HTTP),
            # bc:35:1e:77:b2:59 (.3), 98:03:cf:d2:39:10 (.6),
            # 68:ca:c4:a0:93:09 (.7), 18:d7:17:1f:b2:71 (.10).
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
