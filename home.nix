{ pkgs, inputs, ... }:
{
  imports = [
    ./nixconf/hyprland.nix
    ./nixconf/theme.nix
    ./nixconf/wezterm.nix
    ./nixconf/zsh.nix
    ./nixconf/git.nix
    ./nixconf/neovim.nix
    ./nixconf/zellij.nix
    ./nixconf/btop.nix
    ./nixconf/rofi.nix
    ./nixconf/waybar.nix
    ./nixconf/swaync.nix
    ./nixconf/mpv.nix
    # ./nixconf/syncthing.nix
    ./nixconf/glava.nix
    ./nixconf/sioyek.nix
  ];
  programs = {
    command-not-found.enable = true;
  };
  home = {
    /* The home.stateVersion option does not have a default and must be set */
    stateVersion = "24.05";
    packages = with pkgs; [
      # spotify
      unzip
      unrar-wrapper
      jq
      google-chrome
      playerctl
      nwg-look
      libsForQt5.qt5ct

      # # Can't join voice channels on dorion discord client and it
      # # seems to freeze randomly (wayland/gpu issues maybe)
      # dorion
      # # So having armcord as a fallback for now
      armcord

      # XXX: Suffers from: https://github.com/efroemling/ballistica/discussions/697
      # bombsquad

      (lutris.override {
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
      # mangohud

      bitwarden
      sonixd
      cinnamon.nemo
      calibre
      krita
      blender
      # protonvpn-gui
      lxqt.lxqt-policykit

      wl-clipboard-rs
      any-nix-shell
      android-tools
      # nix-index
      libreoffice-fresh
      transmission-gtk
      chiaki
      diskonaut
      woeusb-ng
      wifite2

      # FIXME: Can't seem to install both these together.
      yubioath-flutter
      # fluffychat

      # element-desktop-wayland
      element-desktop

      python312Packages.ipython
      gnumake
      cmake
      texlive.combined.scheme-full
      pavucontrol

      slack
      # telegram-desktop
      awscli2
      ssm-session-manager-plugin
      nmap

      hyprshot
      wl-gammarelay-rs

      # Repo got removed from NUR: https://github.com/nix-community/NUR/pull/707
      nur.repos.nltch.spotify-adblock
      # So installing directly from my source repo instead
      # ritiek.spotify-adblock
    ];
  };
  programs = {
    home-manager.enable = true;
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
}
