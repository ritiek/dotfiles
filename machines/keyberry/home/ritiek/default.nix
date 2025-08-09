{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule

    # ./../../../../home/gnupg.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/btop.nix

    ./../../../../modules/home/zen-browser.nix

    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/hyprland
    ./../../../../modules/home/theme.nix
    ./../../../../modules/home/ghostty.nix
    # ./../../../../modules/home/wezterm
    ./../../../../modules/home/rofi.nix
    ./../../../../modules/home/waybar
    ./../../../../modules/home/swaync
    ./../../../../modules/home/mpv.nix
    # ./../../../../modules/home/firefox.nix
    # ./../../../../modules/home/librewolf.nix
    ./../../../../modules/home/zen-browser.nix
    # ./../../../../moduleshome/nixconf/syncthing.nix
    # ./../../../../modules/home/glava
    # ./../../../../modules/home/sioyek.nix

  ];

  nixpkgs.overlays = [
    # inputs.nixgl.overlay
    inputs.nur.overlays.default
  ];

  home = {
    stateVersion = "24.11";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      # nixgl.nixGLMesa
      any-nix-shell

      unzip
      unrar-wrapper
      sd
      # diskonaut
      compsize

      iptables
      nmap
      dig
      cryptsetup
      openssl
      sops
      deploy-rs
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
