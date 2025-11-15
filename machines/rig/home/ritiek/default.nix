{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule

    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/ghostty.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
    ./../../../../modules/home/zen-browser.nix
    ./../../../../modules/home/opencode.nix
    ./../../../../modules/home/direnv.nix
    ./../../../../modules/home/rbw.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nur.overlays.default
    inputs.nixpkgs-wayland.overlay

    (final: _prev: {
      stable = import inputs.stable {
        inherit (final) system;
        config.allowUnfree = true;
      };
    })
    (final: _prev: {
      unstable = import inputs.unstable {
        inherit (final) system;
        config.allowUnfree = true;
      };
    })
  ];

  # nixpkgs.config.permittedInsecurePackages = [
  #   "qtwebengine-5.15.19"
  # ];

  home = {
    /* The home.stateVersion option does not have a default and must be set */
    stateVersion = "25.05";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      psmisc
      unixtools.route
      unixtools.xxd
      zip
      unzip
      unrar-wrapper
      tree
      gdb
      iotop
      sd
      playerctl
      nwg-look
      (unstable.lutris.override {
        extraPkgs = pkgs: [
          # # Bombsquad Game
          # python312
          # SDL2
          # libvorbis
          # libGL
          # openal
          # stdenv.cc.cc
        ];
        extraLibraries = pkgs: [
          # python312Packages.tkinter
        ];
      })

      wl-clipboard-rs
      wev
      any-nix-shell
      docker-compose
      cryptsetup
      openssl
      miniserve
      sops
      ssh-to-age
      pavucontrol
      nmap
      dig
      iperf
      nix-tree
      deploy-rs
      nur.repos.nltch.spotify-adblock
    ];
  };

  programs = {
    home-manager.enable = true;
    command-not-found.enable = true;
    jq = {
      enable = true;
      # colors = {
      # };
    };
    ripgrep.enable = true;
    fd.enable = true;
    poetry.enable = true;
    imv.enable = true;

    mangohud = {
      enable = true;
      enableSessionWide = true;
      settings = {
        full = true;
        cpu_load_change = true;
        # Turn off display by default. Use Rshift + F12 to toggle.
        no_display = true;
      };
    };
  };

  services = {
    # playerctld.enable = true;
  };

  xdg.mimeApps.enable = true;
}
