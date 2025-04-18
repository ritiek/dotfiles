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
      storage = {
        type = "local";
        path = "/media/NIX_BINARY_CACHE";
      };
    };
  };
}
