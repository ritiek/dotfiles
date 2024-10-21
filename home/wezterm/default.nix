{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    enableZshIntegration = true;
    extraConfig = builtins.readFile ./wezterm.lua;
  };
}
