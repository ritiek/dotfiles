{ pkgs, config, ... }:
{
  # home.packages = with pkgs; [
  #   unstable.hyprlock
  # ];
  home.file.hyprlock = {
    source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprlock.conf;
    target = "${config.home.homeDirectory}/.config/hypr/hyprlock.conf";
  };
}
