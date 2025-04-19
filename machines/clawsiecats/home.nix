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

  systemd.tmpfiles.settings."10-ssh" = {
    "/nix/persist/home/ritiek".d = {
      mode = "0700";
      user = "ritiek";
    };
    "/nix/persist/home/ritiek/.ssh".d = {
      mode = "0700";
      user = "ritiek";
    };
    "/nix/persist/home/ritiek/.ssh/sops.id_ed25519"."C+" = {
      mode = "0600";
      user = "ritiek";
      argument = "/etc/ssh/ssh_host_ed25519_key";
    };
  };

  # Commenting out as this doesn't look to help with directory creation.
  # environment.persistence."/nix/persist/home/ritiek" = {
  #   users.ritiek = {
  #     directories = [ ];
  #     files = [ ];
  #   };
  # };

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
          directories = [
            # "ballistica-personal-release"
            {
              directory = "ballistica-personal-release";
              # Symlinking as mounting sets nosuid which is not what I want.
              method = "symlink";
            }
          ];
          allowOther = false;
        };
        "/nix/persist/home/${config.home.username}/cache" = {
          directories = [
            ".local/share/nvim"
          ];
          allowOther = false;
        };
      };
      packages = with pkgs; [
        any-nix-shell

        unzip
        unrar-wrapper
        sd
        # diskonaut
        compsize

        docker-compose
        compose2nix

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
