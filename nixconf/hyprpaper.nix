{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    hyprpaper
  ];
  home.file.wallpaper = {
    source = builtins.fetchurl "https://i.imgur.com/gtGew3r.jpg";
    # source = builtins.fetchurl "https://i.imgur.com/tjXNPpW.jpg";
    target = "${config.home.homeDirectory}/Pictures/wallpaper.png";
    # FIXME: `onChange` isn't working right now for some reason.
    # The plan is to update wallpaper automatically if the above URL gets changed.
    onChange = ''
export HYPRLAND_INSTANCE_SIGNATURE="gIbbEr1Sh";
${pkgs.hyprland}/bin/hyprctl hyprpaper unload all;
${pkgs.hyprland}/bin/hyprctl hyprpaper preload ~/Pictures/wallpaper.png;
${pkgs.hyprland}/bin/hyprctl hyprpaper wallpaper eDP-1,~/Pictures/wallpaper.png;
'';
  };
  home.file.hyprpaper = {
    source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprpaper.conf;
    target = "${config.home.homeDirectory}/.config/hypr/hyprpaper.conf";
  };
}
