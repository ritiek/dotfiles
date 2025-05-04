{ pkgs, inputs, config, ... }:
{
  imports = [
    ./../../../../scripts/home/immich-env.nix
    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/zsh
  ];
  home = {
    stateVersion = "24.11";
    username = "immi";
    homeDirectory = "/home/immi";
  };
  programs = {
    command-not-found.enable = true;
    home-manager.enable = true;
  };
}
