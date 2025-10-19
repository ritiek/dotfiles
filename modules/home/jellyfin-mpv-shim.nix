{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    jellyfin-mpv-shim
  ];

  xdg.configFile."jellyfin-mpv-shim/mpv.conf".text = builtins.concatStringsSep "\n" (
    pkgs.lib.mapAttrsToList (name: value: "${name}=${builtins.toString value}") config.programs.mpv.config
  );
}
