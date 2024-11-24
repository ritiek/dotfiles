{ config, pkgs, lib, inputs, ... }:

{
  sops.secrets."restic.htpasswd".owner = "restic";

  # services.devmon.enable = true;
  # services.gvfs.enable = true; 
  # services.udisks2.enable = true;

  services.restic.server = {
    # FALSEEEEEEEEEEEEEEEEEEEEE
    enable = true;
    listenAddress = "0.0.0.0:52525";
    dataDir = "/media";
    # privateRepos = true;
    extraFlags = [
      "--htpasswd-file=${config.sops.secrets."restic.htpasswd".path}"
    ];
    prometheus = true;
  };
}
