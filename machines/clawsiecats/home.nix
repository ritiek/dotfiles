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

  # Create directory `/nix/persist/home/ritiek` here as
  # impermanence's HM module gets a permission denied error
  # as it runs with user perms.
  systemd.tmpfiles.settings."10-home" = {
    # Commenting this out as parent directories seem to be created
    # automatically under root:root so they don't have to be explicity
    # specified here.
    # "/nix/persist/home".d = {
    #   group = "root";
    #   mode = "0755";
    #   user = "root";
    # };
    "/nix/persist/home/ritiek".d = {
      group = "root";
      mode = "0755";
      user = "ritiek";
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
