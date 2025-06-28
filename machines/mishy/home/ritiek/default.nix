{ pkgs, inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule

    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/gnupg.nix
    ./../../../../modules/home/hyprland
    ./../../../../modules/home/theme.nix
    ./../../../../modules/home/ghostty.nix
    # ./../../../../modules/home/wezterm
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/rofi.nix
    ./../../../../modules/home/waybar
    ./../../../../modules/home/swaync
    ./../../../../modules/home/mpv.nix
    # ./../../../../modules/home/firefox.nix
    # ./../../../../modules/home/librewolf.nix
    ./../../../../modules/home/zen-browser.nix
    # ./../../../../moduleshome/nixconf/syncthing.nix
    ./../../../../modules/home/glava
    ./../../../../modules/home/sioyek.nix
  ];

  # TODO: Make adjustments and set this to false.
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
    # (final: _prev: {
    #   local = import inputs.local {
    #     inherit (final) system;
    #     config.allowUnfree = true;
    #   };
    # })
  ];

  home = {
    /* The home.stateVersion option does not have a default and must be set */
    stateVersion = "24.05";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      # spotify
      # local.piano-rs
      psmisc
      zip
      unzip
      unrar-wrapper
      tree
      gdb
      # jq
      # google-chrome
      sd
      playerctl
      nwg-look
      libsForQt5.qt5ct
      libsForQt5.xp-pen-deco-01-v2-driver

      # # Can't join voice channels on dorion discord client and it
      # # seems to freeze randomly (wayland/gpu issues maybe)
      # dorion
      # # So having legcord (armcord) as a fallback for now
      # armcord
      legcord
      # discord

      # osu-lazer-bin
      # XXX: Suffers from: https://github.com/efroemling/ballistica/discussions/697
      # bombsquad

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

      goldwarden
      sonixd
      nemo
      calibre
      unstable.krita
      unstable.blender
      # protonvpn-gui
      lxqt.lxqt-policykit

      wl-clipboard-rs
      wev
      any-nix-shell
      android-tools
      unstable.libreoffice-fresh
      whatsapp-for-linux
      # thunderbird-bin
      # Looks like this available only for darwin:
      # libreoffice-bin
      transmission_4-gtk
      syncplay
      chiaki
      # diskonaut
      # woeusb-ng
      wifite2
      mitmproxy
      docker-compose
      cryptsetup
      openssl

      miniserve
      bore-cli

      sops
      ssh-to-age
      yubikey-manager
      rage
      age-plugin-yubikey
      age-plugin-fido2-hmac

      totp-cli
      # FIXME: Can't seem to install both these together.
      yubioath-flutter
      # fluffychat

      # element-desktop-wayland
      # XXX: error: Package ‘jitsi-meet-1.0.8043’ is marked as insecure, refusing to evaluate.
      # https://github.com/NixOS/nixpkgs/pull/334638#issuecomment-2289025802
      element-desktop
      simplex-chat-desktop
      sqlcipher
      sqldiff

      python312
      python312Packages.pip
      python312Packages.ipython

      rustc
      cargo
      rustfmt
      clippy
      go

      gcc
      gnumake
      cmake
      texlive.combined.scheme-full
      pavucontrol
      # dbeaver-bin
      # sqlitebrowser

      slack
      # telegram-desktop
      awscli2
      ssm-session-manager-plugin
      nmap
      dig
      fastgron
      nap
      imagemagick

      # wl-gammarelay-rs
      # wayvnc
      # wlvncc
      kooha

      deploy-rs
      # inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default

      # Repo got removed from NUR: https://github.com/nix-community/NUR/pull/707
      nur.repos.nltch.spotify-adblock
      # So installing directly from my source repo instead
      # ritiek.spotify-adblock

      # nur.repos.kira-bruneau.habitica
      # inputs.ghostty.packages."${pkgs.system}".default
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
    timidity.enable = true;
    gradle.enable = true;

    zen-browser = {
      enable = true;
      nativeMessagingHosts = with pkgs; [
        ff2mpv-rust
      ];
    };

    thunderbird = {
      enable = true;
      profiles.ritiek = {
        isDefault = true;
      };
    };

    joplin-desktop = {
      enable = true;
    };

    freetube = {
      enable = true;
      settings = {
        allowDashAv1Formats = true;
        checkForUpdates = false;
        defaultQuality = "1080";
        baseTheme = "catppuccinMocha";
      };
    };

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

  # services = {
  #   playerctld.enable = true;
  # };

  xdg.mimeApps.enable = true;
}
