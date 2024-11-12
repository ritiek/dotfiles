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
      ./../../modules/home/zsh
      ./../../modules/home/neovim
    ];
    home.stateVersion = "24.05";
  };

  home-manager.users.ritiek = { config, ... }: {
    imports = [
      inputs.impermanence.nixosModules.home-manager.impermanence
      ./../../modules/home/zsh
      ./../../modules/home/git
      ./../../modules/home/neovim
      ./../../modules/home/zellij.nix
      ./../../modules/home/btop.nix
    ];
    home = {
      stateVersion = "24.05";
      persistence = {
        "/nix/persist/home/${config.home.username}/files" = {
          files = [
            ".zsh_history"
          ];
          allowOther = false;
        };
        "/nix/persist/home/${config.home.username}/cache" = {
          directories = [
            ".local/share/nvim"
            # {
            #   directory = ".local/share/nvim";
            #   method = "symlink";
            # }
            # {
            #   directory = ".local/state/nvim";
            #   method = "symlink";
            # }
          ];
          # files = [
          #   ".nvim-lazy-lock.json"
          # ];
          allowOther = false;
        };
      };
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
