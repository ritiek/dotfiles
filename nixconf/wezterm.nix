{ pkgs, ... }:
{
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile /etc/nixos/chezmoi/dot_wezterm.lua;
  };
}
