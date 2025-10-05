{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = builtins.fromJSON (builtins.readFile ./config);
    };
    style = builtins.readFile ./style.css;
  };
}
