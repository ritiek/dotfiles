{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = builtins.fromJSON (builtins.readFile /etc/nixos/chezmoi/dot_config/waybar/config);
    };
    style = builtins.readFile /etc/nixos/chezmoi/dot_config/waybar/style.css;
  };
}
