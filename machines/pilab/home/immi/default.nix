{ pkgs, inputs, config, ... }:
{
  imports = [
    # inputs.home-manager.nixosModules.home-manager
  ];
  home-manager.users.immi = { osConfig, config, ... }: {
    imports = [
      ./../../../../scripts/home/immich-env.nix
      ./../../../../modules/home/sops.nix
      ./../../../../modules/home/zsh
    ];
    home.stateVersion = "24.11";
    programs = {
      command-not-found.enable = true;
      home-manager.enable = true;
    };
  };
}
