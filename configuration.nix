# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, modulesPath, options, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      ./hardware-configuration.nix
      ./home.nix
    ];

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Enable KDE.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Configure keymap in X11
  # services.xserver = {
  #   layout = "us";
  #   xkbVariant = "";
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ritiek = {
    isNormalUser = true;
    description = "Ritiek Malhotra";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "audio"
      "input"
      "dialout"
      "polkituser"
    ];
    # packages = with pkgs; [
    #   firefox
    # ];
    shell = pkgs.zsh;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Flakes use Git to pull dependencies from data sources 
    wget
    curl
    # wl-gammarelay-rs
    swayidle
    swaylock-effects
    swayosd
    # nemo
    brightnessctl
    # hyprshot
    ripgrep
    fd
    keychain
    btop
    gparted
    xclip
    xorg.xhost
    imv
    yubico-pam
    pam_u2f

    libnotify
    lshw
    glxinfo
    intel-gpu-tools
    aircrack-ng
    linuxPackages.usbip
    # nur.repos.nltch.spotify-adblock
  ];

  programs.git.enable = true;
  programs.neovim.enable = true;
  # programs.nixvim.enable = true;

  # programs.nix-ld = {
  #   enable = true;
  #   # libraries = options.programs.nix-ld.libraries.default ++ (with pkgs; [ yourlibrary ]);
  #   libraries = options.programs.nix-ld.libraries.default;
  # };
  # environment.variables = {
  #   NIX_LD = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
  # };

  services.udev.packages = [ pkgs.swayosd ];
  # services.swayosd.enable = true;

  systemd = {
    services = {
      swayosd-libinput-backend = {
        description = "swayosd-libinput-backend";
	enable = true;
	path = [
	  pkgs.coreutils
	  pkgs.swayosd
	];
        script = ''
${pkgs.coreutils}/bin/sleep 30s
echo starting
sudo ${pkgs.swayosd}/bin/swayosd-libinput-backend
	'';
        wantedBy = [ "graphical-session.target" ];
        # wants = [ "graphical-session.target" ];
        # after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = 10;
          TimeoutStopSec = 60;
	  User = "root";
	  Group = "root";
        };
      };
    };

    user.services = {
      polkit-gnome-authentication-agent-1 = {
        description = "polkit-gnome-authentication-agent-1";
	enable = true;
        wantedBy = [ "graphical-session.target" ];
        wants = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  services.tailscale.enable = true;
  services.blueman.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.hyprland.enable = true;
  # programs.hyprland = { # or wayland.windowManager.hyprland
  #   enable = true;
  #   enableNvidiaPatches = true;
  #   # xwayland.enable = true;
  # };

  programs.zsh.enable = true;
  # users.defaultUserShell = pkgs.zsh;
  security.polkit.enable = true;

  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
    unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {};
  };

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      cantarell-fonts
      material-design-icons
      noto-fonts

      (nerdfonts.override {
        fonts = [
          "FantasqueSansMono"
          "InconsolataGo"
          "JetBrainsMono"
          # "NotoSansMono"
        ];
      })
    ];
  };

  environment.variables.EDITOR = "nvim";

  system.autoUpgrade.enable = true;
  # system.autoUpgrade.allowReboot = true;
}
