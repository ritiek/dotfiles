{ pkgs, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.zip";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.ritiek = { config, lib, ... }: {
    imports = [
      ./nixconf/hyprland.nix
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
      ./nixconf/sioyek.nix
    ];
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
	armcord
	bitwarden
	sonixd
	cinnamon.nemo
	calibre
	krita
	# protonvpn-gui
	lxqt.lxqt-policykit
	yubioath-flutter
	wl-clipboard-rs
	any-nix-shell
	android-tools
	# nix-index
	lutris

	gnumake
	cmake
	texlive.combined.scheme-full

        slack
        # telegram-desktop
	awscli2
	ssm-session-manager-plugin

	hyprshot
	wl-gammarelay-rs
	nur.repos.nltch.spotify-adblock
      ];
      pointerCursor = {
        x11.enable = true;
        name = "Qogir";
        package = pkgs.qogir-icon-theme;
        size = 64;
        gtk.enable = true;
      };
    };

    /* Here goes the rest of your home-manager config, e.g. home.packages = [ pkgs.foo ]; */

    # xdg.configFile."nvim".source = pkgs.stdenv.mkDerivation {
    #   name = "NvChad";
    #   buildInputs = with pkgs; [
    #     # makeWrapper
    #     neovim
    #   ];
    #   src = pkgs.fetchFromGitHub {
    #     owner = "NvChad";
    #     repo = "NvChad";
    #     rev = "f17e83010f25784b58dea175c6480b3a8225a3e9";
    #     hash = "sha256-P5TRjg603/7kOVNFC8nXfyciNRLsIeFvKsoRCIwFP3I=";
    #   };
    #   installPhase = ''
    #   mkdir -p $out
    #   cp -r ./* $out/
    #   cd $out/
    #   cp -r ${./nvchad} $out/lua/custom
    #   '';
    # };

    programs.command-not-found.enable = true;

    gtk = {
      enable = true;
      cursorTheme = {
        name = "Qogir";
	package = pkgs.qogir-icon-theme;
        size = 24;
      };
      font = {
        name = "Cantarell";
        package = pkgs.cantarell-fonts;
	size = 11;
      };
      iconTheme = {
        name = "Dracula";
        package = pkgs.dracula-icon-theme;
      };
      # theme = {
      #   name = "Catppucin-Mocha-Standard-Red-Dark";
      #   package = pkgs.catppuccin-gtk.override {
      #     # accents = [ "lavender" ];
      #     accents = [ "red-dark" ];
      #     size = "standard";
      #     variant = "mocha";
      #   };
      # };
      theme = {
        name = "Dracula";
        package = pkgs.dracula-theme;
      };
      gtk3.extraConfig = {
        gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
        gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
        gtk-button-images = 0;
        gtk-menu-images = 0;
        gtk-enable-event-sounds = 1;
        gtk-enable-input-feedback-sounds = 0;
        gtk-xft-antialias = 1;
        gtk-xft-hinting = 1;
        gtk-xft-hintstyle = "hintslight";
        gtk-xft-rgba = "rgb";
        gtk-application-prefer-dark-theme = 1;
      };
    };
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
