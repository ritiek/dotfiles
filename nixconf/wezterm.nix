{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = inputs.wezterm-flake.packages.${pkgs.system}.default;
    enableZshIntegration = true;
    extraConfig = builtins.readFile ../chezmoi/dot_wezterm.lua;
  };
}
