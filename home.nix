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
	libreoffice-fresh
	transmission-gtk
	chiaki

	gnumake
	cmake
	texlive.combined.scheme-full
	pavucontrol

        slack
        # telegram-desktop
	awscli2
	ssm-session-manager-plugin

	hyprshot
	wl-gammarelay-rs
	nur.repos.nltch.spotify-adblock
      ];
    };
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
