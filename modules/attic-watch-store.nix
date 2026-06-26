{ config, pkgs, ... }:
let
  server = "pilab";
  cache = "attic-action";
  endpoint = "http://pilab.lion-zebra.ts.net:7080/";
in
{
  # Dedicated system user/group so the sops secret can be owned readably
  # (DynamicUser would get an unpredictable UID the secret can't be owned to).
  users.groups.attic-watch-store = {};
  users.users.attic-watch-store = {
    isSystemUser = true;
    group = "attic-watch-store";
  };

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
      # -j 1: serialize uploads from this background pusher. The atticd backend
      # is PostgreSQL and handles concurrent writers fine, but this service is a
      # low-priority store watcher where upload throughput is not critical, so we
      # keep it to a single connection to stay gentle on the cache server.
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store --jobs 1 ${server}:${cache}";
      Restart = "on-failure";
      RestartSec = 10;
      User = "attic-watch-store";
      Group = "attic-watch-store";
    };
  };
}
