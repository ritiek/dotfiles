{ pkgs, config, ... }:
{
  home.file.hyprpaper = {
    source = config.lib.file.mkOutOfStoreSymlink ./chezmoi/dot_config/hypr/hyprpaper.conf;
    target = "${config.home.homeDirectory}/.config/hypr/hyprpaper.conf";
  };
}
