{ pkgs, inputs, config, ... }:
{
  imports = [
    ./ritiek
    ./immi
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };
  };
  environment.pathsToLink = [
    "/share/zsh"
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];
  home-manager.users.root = {
    imports = [
      ./../../../modules/home/zsh
      ./../../../modules/home/neovim
    ];
    home.stateVersion = "24.11";
  };
}
