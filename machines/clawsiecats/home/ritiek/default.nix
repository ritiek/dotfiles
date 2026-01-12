{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.sops-nix.homeManagerModule

    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    # ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
    # ./../../../../modules/home/opencode.nix
    ./../../../../modules/home/direnv.nix
  ];

  nixpkgs.overlays = [
    # Bun baseline overlay for CPUs without AVX2
    (final: prev: {
      bun = prev.bun.overrideAttrs (oldAttrs: {
        src = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${oldAttrs.version}/bun-linux-x64-baseline.zip";
          hash = "sha256-f/CaSlGeggbWDXt2MHLL82Qvg3BpAWVYbTA/ryFpIXI=";
        };
      });
    })
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
          ".ssh"
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
          ".local/share/atuin"
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
      deploy-rs

      miniserve
      bore-cli
      iperf
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
