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
      ./../../../modules/home/zsh
      ./../../../modules/home/neovim
    ];
    home.stateVersion = "24.11";
  };

  home-manager.users.ritiek = {
    imports = [
      # ./../../../home/gnupg.nix
      ./../../../modules/home/zsh
      ./../../../modules/home/git
      ./../../../modules/home/neovim
      ./../../../modules/home/zellij.nix
      ./../../../modules/home/btop.nix
    ];
    home = {
      stateVersion = "24.11";
      packages = with pkgs; [
        any-nix-shell

        unzip
        unrar-wrapper
        sd
        diskonaut
        compsize

        iptables
        nmap
        dig
        cryptsetup
        openssl
        sops
        deploy-rs

        miniserve
        bore-cli
      ];
    };
    programs = {
      command-not-found.enable = true;
      home-manager.enable = true;
      jq.enable = true;
      ripgrep.enable = true;
      fd.enable = true;
    };
  };
}
