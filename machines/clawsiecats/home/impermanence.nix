{ pkgs, inputs, config, ... }:

{
  imports = [
    "${inputs.impermanence}/home-manager.nix"
    ./default.nix
  ];
  home = {
    persistence."/nix/persist/${config.home.homeDirectory}" = {
      files = [
        ".zsh_history"
        # ".local/share/nvim"
      ];
    };
  };
}
