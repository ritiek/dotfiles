{ config, ... }:
{
  sops.secrets."3proxy.users" = {
    mode = "0444";
  };
  services._3proxy = {
    enable = true;
    usersFile = config.sops.secrets."3proxy.users".path;
    services = [
      {
        type = "proxy";
        bindAddress = "0.0.0.0";
        bindPort = 8888;
        auth = [ "strong" ];
        acl = [
          { rule = "allow"; }
        ];
      }
    ];
  };
}
