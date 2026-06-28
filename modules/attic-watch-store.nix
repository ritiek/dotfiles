{ config, pkgs, lib, ... }:
let
  server = "pilab";
  cache = "attic-action";
  endpoint = "http://pilab.lion-zebra.ts.net:7080/";

  # Derive the attic-push exclude list from the trusted cache signing keys so
  # adding a cache in ../substituters.nix automatically stops re-pushing its
  # paths. A signature is "<signer-name>:<sig>"; the signer name is what the
  # sigs column stores, so we match on the part before the first ":".
  trustedSigners =
    map (k: builtins.head (lib.splitString ":" k))
      (import ../substituters.nix).trusted-public-keys;
  excludeClause =
    lib.concatMapStringsSep " AND "
      (n: "sigs NOT LIKE '%${n}%'")
      trustedSigners;
in
{
  # Dedicated system user/group so the sops secret can be owned readably
  # (DynamicUser would get an unpredictable UID the secret can't be owned to).
  users.groups.attic-watch-store = {};
  users.users.attic-watch-store = {
    isSystemUser = true;
    group = "attic-watch-store";
  };

  nix.settings.trusted-users = [ "attic-watch-store" ];

  # Manual bulk-push: enumerate locally-built store paths (signatures NOT from a
  # trusted upstream cache) straight from the Nix sqlite DB — bypasses the nix
  # daemon so it never loads the whole store into RAM. Piped into a single attic
  # push under a memory-capped transient scope (kernel kills only the scope on
  # overrun, never the box). `sudo` on sqlite3: the DB is root-only on some hosts.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "attic-push" ''
      set -euo pipefail
      sudo ${pkgs.sqlite}/bin/sqlite3 'file:/nix/var/nix/db/db.sqlite?immutable=1' "
        SELECT path FROM ValidPaths
        WHERE path NOT LIKE '%.drv'
        AND (sigs IS NULL OR (
          ${excludeClause}
        ))
      " | sudo systemd-run --scope -q --property=MemoryMax=6G --property=MemorySwapMax=0 \
        --nice=19 --setenv=XDG_CONFIG_HOME=/etc \
        ${pkgs.util-linux}/bin/ionice -c idle \
        ${pkgs.util-linux}/bin/chrt --idle 0 \
        ${pkgs.attic-client}/bin/attic push ${server}:${cache} --stdin -j 1
    '')
  ];

  # Read+push token for the attic-action cache (same token used by GitHub Actions).
  sops.secrets."attic.token" = {
    owner = "attic-watch-store";
    group = "attic-watch-store";
    mode = "0400";
  };

  # Attic reads its config from $XDG_CONFIG_HOME/attic/config.toml.
  # We point the service's XDG_CONFIG_HOME at /etc and use `token-file` so the
  # token is never written to disk in plaintext outside the sops-managed secret.
  environment.etc."attic/config.toml".text = ''
    default-server = "${server}"

    [servers.${server}]
    endpoint = "${endpoint}"
    token-file = "${config.sops.secrets."attic.token".path}"
  '';

  systemd.services.attic-watch-store = {
    description = "Attic watch-store: auto-push new Nix store paths to ${cache}";
    after = [ "network-online.target" "atticd.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.XDG_CONFIG_HOME = "/etc";
    serviceConfig = {
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store ${server}:${cache} -j 1";
      Restart = "on-failure";
      RestartSec = 10;
      User = "attic-watch-store";
      Group = "attic-watch-store";
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
    };
  };
}
