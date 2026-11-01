{ pkgs, inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule

    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/gnupg.nix
    ./../../../../modules/home/niri
    ./../../../../modules/home/theme.nix
    ./../../../../modules/home/ghostty.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
    ./../../../../modules/home/rofi.nix
    ./../../../../modules/home/waybar
    ./../../../../modules/home/swaync
    ./../../../../modules/home/mpv.nix
    ./../../../../modules/home/jellyfin-mpv-shim.nix
    ./../../../../modules/home/zen-browser.nix
    ./../../../../modules/home/direnv.nix
    ./../../../../modules/home/lutris.nix
    ./../../../../modules/home/opencode
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

  home = {
    stateVersion = "26.11";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      playerctl
      nwg-look
      libsForQt5.qt5ct
      lxqt.lxqt-policykit
      wl-clipboard-rs
      pavucontrol
      nemo
      unzip
    ];
  };

  programs = {
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
    mangohud = {
      enable = true;
      enableSessionWide = true;
      settings = {
        full = true;
        cpu_load_change = true;
        no_display = true;
      };
    };
  };

  xdg.mimeApps.enable = true;
}
