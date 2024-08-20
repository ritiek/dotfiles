{ pkgs, inputs, config, ... }:
{
  # programs.wezterm = {
  #   enable = true;
  #   package = pkgs.stable.wezterm;
  #   extraConfig = builtins.readFile ../chezmoi/dot_wezterm.lua;
  # };
  # The above isn't working right now.
  #
  # So using wezterm's flake input which seems
  # to be working fine at the moment.
  #
  # https://github.com/wez/wezterm/issues/5990
  home.file = {
    wezterm = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_wezterm.lua;
      target = "${config.home.homeDirectory}/.wezterm.lua";
    };
  };
  home.packages = with pkgs; [
    inputs.wezterm-flake.packages.${pkgs.system}.default
  ];
}
