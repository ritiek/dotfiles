{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = builtins.fromJSON (builtins.readFile ../chezmoi/dot_config/waybar/config);
    };
    style = builtins.readFile ../chezmoi/dot_config/waybar/style.css;
  };
}
