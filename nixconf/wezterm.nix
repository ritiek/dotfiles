{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = inputs.wezterm-flake.packages.${pkgs.system}.default;
    extraConfig = builtins.readFile ../chezmoi/dot_wezterm.lua;
  };
}
