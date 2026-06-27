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

  nix.settings.trusted-users = [ "attic-watch-store" ];

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
