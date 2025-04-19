{ config, pkgs, ... }:
{
  sops.secrets."atticd.env" = {};
  environment.systemPackages = with pkgs; [
    attic-client
  ];
  services.atticd = {
    enable = true;
    environmentFile = config.sops.secrets."atticd.env".path;
    settings = {
      compression = {
        type = "zstd";
        level = 9;
      };
      database = {
        url = "sqlite://${config.fileSystems.nix-binary-cache.mountPoint}/server.db?mode=rwc";
      };
      storage = {
        type = "local";
        path = config.fileSystems.nix-binary-cache.mountPoint;
      };
    };
  };
}
