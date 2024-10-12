{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    syncthing
  ];
  services.syncthing = {
    enable = true;
    tray.enable = true;
  };
}
