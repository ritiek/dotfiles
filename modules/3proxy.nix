{ config, ... }:
{
  # 3proxy expands `users $file` once while parsing its config at startup and
  # has no ExecReload wired up by the NixOS module, so a rotated password file
  # is ignored until the daemon restarts.
  sops.secrets."3proxy.users" = {
    mode = "0444";
    restartUnits = [ "3proxy.service" ];
  };
  services._3proxy = {
    enable = true;
    usersFile = config.sops.secrets."3proxy.users".path;
    services = [
      {
        type = "proxy";
        bindAddress = "0.0.0.0";
        bindPort = 8090;
        auth = [ "strong" ];
        acl = [
          { rule = "allow"; }
        ];
        # Hostnames still resolve to IPv4 first, but IPv6 targets become reachable
        # (3proxy's default -4 refuses them). ocfree picks the family per request by
        # asking for the IP address itself.
        extraArguments = "-46";
      }
    ];
  };
}
