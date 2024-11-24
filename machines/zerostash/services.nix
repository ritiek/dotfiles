{ config, pkgs, lib, inputs, ... }:

{
  sops.secrets."restic.htpasswd".owner = "restic";
  services.restic.server = {
    enable = true;
    listenAddress = "0.0.0.0:52525";
    dataDir = "/restic";
    # privateRepos = true;
    extraFlags = [
      "--htpasswd-file=${config.sops.secrets."restic.htpasswd".path}"
    ];
    prometheus = true;
  };
}
