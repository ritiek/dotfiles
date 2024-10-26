{ pkgs, inputs, ... }:
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

  home-manager.users.ritiek = {
    imports = [
      ./../../home/gnupg.nix
      ./../../home/hyprland
      ./../../home/theme.nix
      ./../../home/wezterm
      ./../../home/zsh
      ./../../home/git
      ./../../home/neovim
      ./../../home/zellij.nix
      ./../../home/btop.nix
      ./../../home/rofi.nix
      ./../../home/waybar
      ./../../home/swaync
      ./../../home/mpv.nix
      ./../../home/firefox.nix
      # ./../../home/nixconf/syncthing.nix
      ./../../home/glava
      ./../../home/sioyek.nix
    ];
    home = {
      /* The home.stateVersion option does not have a default and must be set */
      stateVersion = "24.05";
      packages = with pkgs; [
        # spotify
        # local.piano-rs
        unzip
        unrar-wrapper
        tree
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
        ## # So having legcord (armcord) as a fallback for now
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

        bitwarden
        sonixd
        nemo
        # unstable.calibre
        unstable.rita
        unstable.blender
        # protonvpn-gui
        lxqt.lxqt-policykit

        wl-clipboard-rs
        wev
        any-nix-shell
        android-tools
        unstable.libreoffice-fresh
        # Looks like this available only for darwin:
        # libreoffice-bin
        transmission_4-gtk
        chiaki
        diskonaut
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

        # FIXME: Can't seem to install both these together.
        yubioath-flutter
        # fluffychat

        # element-desktop-wayland
        # XXX: error: Package ‘jitsi-meet-1.0.8043’ is marked as insecure, refusing to evaluate.
        # https://github.com/NixOS/nixpkgs/pull/334638#issuecomment-2289025802
        unstable.element-desktop

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

        slack
        # telegram-desktop
        awscli2
        ssm-session-manager-plugin
        nmap
        dig
        fastgron
        nap

        wl-gammarelay-rs
        wayvnc
        wlvncc

        deploy-rs
        # inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default

        # Repo got removed from NUR: https://github.com/nix-community/NUR/pull/707
        nur.repos.nltch.spotify-adblock
        # So installing directly from my source repo instead
        # ritiek.spotify-adblock
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

    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "application/pdf" = ["sioyek.desktop"];
      };
      defaultApplications = {
        "application/pdf" = ["sioyek.desktop"];
      };
    };
  };
}
