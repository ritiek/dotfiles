{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.sops-nix.homeManagerModule

    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/btop.nix
  ];
  home = {
    stateVersion = "24.05";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
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
      psmisc

      unzip
      unrar-wrapper
      sd
      # diskonaut
      compsize

      # docker-compose
      compose2nix

      iptables
      nmap
      dig
      cryptsetup
      openssl
      sops
      ssh-to-age

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
}
