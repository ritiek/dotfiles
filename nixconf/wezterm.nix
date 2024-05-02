{ pkgs, ... }:
{
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ../chezmoi/dot_wezterm.lua;
  };
}
