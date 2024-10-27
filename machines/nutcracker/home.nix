{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
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
      ./../../common/home/zsh
      ./../../common/home/git
      ./../../common/home/neovim
      ./../../common/home/zellij.nix
      ./../../common/home/btop.nix
    ];
    home = {
      stateVersion = "24.11";
      packages = with pkgs; [
        wifite2
      ];
    };
  };
}
