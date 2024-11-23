{ config, pkgs, lib, inputs, ... }:

{
  sops.secrets."restic.htpasswd".owner = "restic";
  services = {
    # uptime-kuma = {
    #   enable = true;
    #   appriseSupport = false;
    #   settings = {
    #     HOST = "0.0.0.0";
    #     PORT = "3001";
    #     # FIXME: This results in a permission error during nixos-rebuild.
    #     # DATA_DIR = lib.mkForce "/root/uptime-kuma";
    #   };
    # };
    restic.server = {
      enable = true;
      listenAddress = "0.0.0.0:52525";
      dataDir = "/restic";
      # privateRepos = true;
      extraFlags = [
        "--htpasswd-file=${config.sops.secrets."restic.htpasswd".path}"
      ];
      prometheus = true;
    };
  };
}
