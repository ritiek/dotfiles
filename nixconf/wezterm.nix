{ pkgs, ... }:
{
  # TODO: Remove kitty once this issue resolves:
  # https://github.com/wez/wezterm/issues/5990
  programs.kitty.enable = true;
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ../chezmoi/dot_wezterm.lua;
  };
}
