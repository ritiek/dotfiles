{ pkgs, config, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    enableNvidiaPatches = true;
    # xwayland.enable = false;
    systemd = {
      enable = true;
      variables = ["-all"];
    };
    extraConfig = builtins.readFile ../chezmoi/dot_config/hypr/hyprland.conf;
  };
  home.packages = with pkgs; [
    unstable.hypridle
    unstable.hyprlock
    hyprpaper
  ];
  home.file = {
    hyprland = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprland;
      target = "${config.home.homeDirectory}/.config/hypr/hyprland";
    };
    hypridle = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hypridle.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hypridle.conf";
    };
    hyprlock = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprlock.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hyprlock.conf";
    };
    hyprpaper = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprpaper.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hyprpaper.conf";
    };
    wallpaper = {
      source = builtins.fetchurl "https://i.imgur.com/gtGew3r.jpg";
      # source = builtins.fetchurl "https://i.imgur.com/tjXNPpW.jpg";
      target = "${config.home.homeDirectory}/Pictures/wallpaper.jpg";
      # FIXME: `onChange` isn't working right now for some reason.
      # The plan is to update wallpaper automatically if the above URL gets changed.
      onChange = ''
export HYPRLAND_INSTANCE_SIGNATURE="gIbbEr1Sh";
${pkgs.hyprland}/bin/hyprctl hyprpaper unload all;
${pkgs.hyprland}/bin/hyprctl hyprpaper preload ~/Pictures/wallpaper.jpg;
${pkgs.hyprland}/bin/hyprctl hyprpaper wallpaper eDP-1,~/Pictures/wallpaper.jpg;
'';
    };
  };
}
