{ config, lib, pkgs, inputs, ... }:


let
  domain = "clawsiecats.omg.lol";
in
{
  sops.secrets = {
    "tailscale.authkey" = {};
    "headscale.noise_private.key" = {
      sopsFile = ./secrets.yaml;
      key = "noise_private.key";
      mode = "0600";
    };
    "headscale.derp_server_private.key" = {
      sopsFile = ./secrets.yaml;
      key = "derp_server_private.key";
      mode = "0600";
    };
    "headscale.db.sqlite" = {
      sopsFile = ./db.sqlite;
      format = "binary";
      mode = "0600";
    };
  };

  environment.persistence."/nix/persist/system" = {
    directories = [
      "/var/lib/headscale"
    ];
  };

  # Seed headscale files from sops secrets on first boot only.
  # sops-nix deploys secrets to /run/secrets/ (tmpfs). The path override to
  # /var/lib/headscale/ does not work because the impermanence bind mount for
  # that directory comes up after sops-nix runs in stage-2, shadowing anything
  # sops wrote there. So we copy manually here, skipping if already persisted.
  systemd.services.headscale-db-seed = {
    description = "Seed headscale data from sops secrets (first boot only)";
    wantedBy = [ "headscale.service" ];
    before = [ "headscale.service" ];
    after = [ "sops-nix.service" "var-lib-headscale.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for src_dest in \
        "${config.sops.secrets."headscale.noise_private.key".path}:/var/lib/headscale/noise_private.key" \
        "${config.sops.secrets."headscale.derp_server_private.key".path}:/var/lib/headscale/derp_server_private.key" \
        "${config.sops.secrets."headscale.db.sqlite".path}:/var/lib/headscale/db.sqlite"
      do
        src="''${src_dest%%:*}"
        dest="''${src_dest##*:}"
        if [ ! -f "$dest" ]; then
          install -m 0600 -o root -g root "$src" "$dest"
        fi
      done
    '';
  };

  systemd.services.tailscaled-autoconnect = {
    after = [ "headscale.service" ];
    wants = [ "headscale.service" ];
    serviceConfig = {
      # On fresh boots, re-auth with headscale (which is also on this machine)
      # can take several minutes: seed → headscale restart → tailscale login.
      # Extend the start timeout well beyond systemd's default 90 s.
      TimeoutStartSec = lib.mkForce "300";
    };
  };

  systemd.services.headplane = {
    after = [ "headscale.service" ];
    wants = [ "headscale.service" ];
    serviceConfig = {
      TimeoutStartSec = lib.mkForce "300";
    };
  };

  services = {
    headscale = {
      enable = true;
      # XXX: Required for Syncthing.
      user = "root";
      # group = "root";
      address = "0.0.0.0";
      port = 8088;
      settings = {
        server_url = "https://controlplane.${domain}";
        # listen_addr is auto-generated from address:port
        # log.level = "debug";
        dns = {
          search_domains = [ "lion-zebra.ts.net" ];
          magic_dns = true;
          nameservers.global = [
            # PiHole (pilab)
            "100.64.0.2"
            # Mullvad
            "194.242.2.2"
            "2a07:e340::2"
          ];
          base_domain = "lion-zebra.ts.net";
        };
        derp = {
          server = {
            enabled = true;
            # NOTE: `ipv4` is deliberately left unset. The embedded DERP is
            # already reachable without it (peers show `relay "headscale"`,
            # https://controlplane.${domain}/derp returns 426 Upgrade Required
            # and UDP/3479 STUN answers from outside), so hardcoding the public
            # IP buys nothing and rots -- the value previously parked here
            # (46.8.224.87) was already stale; it is now 31.56.178.40.
            stun_listen_addr = "0.0.0.0:3479";
            region_code = "headscale";
            region_name = "Headscale Embedded DERP";
            region_id = 999;
            # Setting this to false lets people outside my Headscale network use
            # this DERP relay.
            verify_clients = true;
          };
          # Hand out Tailscale's public derpmap *in addition to* the embedded
          # region above, so every node has a nearby relay to fall back on.
          #
          # This was briefly set to [] to force clawsiecats<->pilab off the
          # shared public "blr" relay, which was capping Immich transfers at
          # ~18 kB/s. That worked (~3.3 MB/s) but treated the symptom: pilab
          # could not hole punch to this box at all and fell back to a relay
          # permanently.
          #
          # The real cause was a wedged NAT mapping for pilab's UDP source
          # port 41641 upstream (kept alive indefinitely by disco's own
          # retries -- see the comment at services.tailscale.port in
          # machines/pilab/default.nix for the full story); pilab now runs
          # port = 0 and peers directly. An earlier note here claimed the port
          # was never the cause because forcing pilab back to 41641 still
          # connected directly -- that test was invalid: it flipped the port
          # while a direct path was already up and being held open by
          # keepalives, so it never exercised a cold path.
          #
          # So there is no reason to strip the public regions -- doing so only
          # made this box a single point of failure and would force e.g. two
          # India-based peers to relay through the US (~220ms) instead of blr
          # (~33ms) whenever they could not connect directly.
          urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
          paths = [];
          auto_update_enabled = false;
          update_frequency = "24h";
        };
        # Introducing a policy replaces headscale's implicit allow-all, so the
        # first ACL below must stay: it reproduces the previous "no policy"
        # behaviour exactly. The policy only exists to carry the peer-relay
        # grant.
        #
        # Peer relay (UDP WireGuard forwarding, headscale >= 0.29 / tailscale
        # >= 1.86): when two peers cannot hole punch a direct path, they relay
        # via this box's UDP relay port at near line rate instead of falling
        # back to DERP (TCP-in-TCP, ~11-14 Mbit/s measured). DERP stays as the
        # mandatory disco signaling channel and data path of last resort --
        # CallMeMaybe/CallMeMaybeVia/Allocate* messages are only ever sent over
        # DERP, so it must not be removed. Path priority per pair, re-evaluated
        # continuously: direct > peer-relay > DERP.
        #
        # src is "*" against upstream's advice (they suggest scoping to nodes
        # behind strict NATs): with a single relay and a small fleet the worst
        # case of a wide src is a peer pair relaying here instead of DERP,
        # which is the point.
        #
        # NOTE: the policy file lives in the nix store, so headplane's ACL
        # editor can view but not modify it. Manage it here.
        policy = {
          mode = "file";
          path = pkgs.writeText "headscale-policy.json" (builtins.toJSON {
            hosts = {
              clawsiecats = "100.64.0.1/32";
            };
            acls = [
              {
                action = "accept";
                src = [ "*" ];
                dst = [ "*:*" ];
              }
            ];
            grants = [
              {
                src = [ "*" ];
                dst = [ "clawsiecats" ];
                app = {
                  "tailscale.com/cap/relay" = [ ];
                };
              }
            ];
          });
        };
      };
    };

    # Act as a peer relay server (see the policy.grants comment above). Fixed
    # port because the firewall rule below must match it; must be reachable
    # over UDP from every node that may use the relay.
    tailscale.extraSetFlags = [ "--relay-server-port=41642" ];

    headplane = {
      enable = true;
      # agent.enable = false;
      # agent = {
      #   # As an example only.
      #   # Headplane Agent hasn't yet been ready at the moment of writing the doc.
      #   enable = true;
      #   settings = {
      #     HEADPLANE_AGENT_DEBUG = true;
      #     HEADPLANE_AGENT_HOSTNAME = "localhost";
      #     HEADPLANE_AGENT_TS_SERVER = "https://example.com";
      #     HEADPLANE_AGENT_TS_AUTHKEY = "xxxxxxxxxxxxxx";
      #     HEADPLANE_AGENT_HP_SERVER = "https://example.com/admin/dns";
      #     HEADPLANE_AGENT_HP_AUTHKEY = "xxxxxxxxxxxxxx";
      #   };
      # };
      settings = {
        server = {
          host = "127.0.0.1";
          port = 3000;
          cookie_secret_path = pkgs.writeText "headplane-cookie-secret" "xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX";
          cookie_secure = false;
        };
        headscale = {
          url = "http://127.0.0.1:8088";
          config_strict = true;
        };
        integration = {
          proc.enabled = true;
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      # NGINX and ACME
      80
      443
      # Coturn TURN/STUN
      3479
    ];
    allowedUDPPorts = [
      # DERP STUN
      3479
      41641
      # Tailscale peer relay (--relay-server-port above)
      41642
    ];
  };
}
