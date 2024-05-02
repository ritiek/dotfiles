# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, modulesPath, options, ... }:

{
  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
        inherit pkgs;
      };
      unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {};
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      ./hardware-configuration.nix
      ./graphics.nix
      ./environment.nix
      ./home.nix
    ];

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
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
  };

  # Enable networking
  networking = {
    networkmanager.enable = true;

    # Open ports in the firewall.
    # firewall.allowedTCPPorts = [ ... ];
    # firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    firewall.enable = false;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # wireless = {
    #   enable = true;
    #   networks = {
    #     testing = {
    #       psk = "abcde";
    #     };
    #   };
    # };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users.ritiek = {
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
      shell = pkgs.zsh;
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      # Flakes use Git to pull dependencies from data sources 
      wget
      curl
      swayosd
      brightnessctl
      ripgrep
      fd
      keychain
      btop
      gparted
      xclip
      xorg.xhost
      imv
      # helix
      yubico-pam
      pam_u2f
      parallel

      xorg.xeyes
      usbutils
      libnotify
      lshw
      pv
      glxinfo
      intel-gpu-tools
      aircrack-ng
      linuxPackages.usbip
    ];

    variables.EDITOR = "nvim";
  };

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
          ${pkgs.coreutils}/bin/sleep 30s;
          echo starting;
          sudo ${pkgs.swayosd}/bin/swayosd-libinput-backend;
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

  # Enable sound with pipewire.
  sound.enable = true;

  hardware = {
    pulseaudio.enable = false;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    # Enable the OpenSSH daemon.
    # openssh.enable = true;

    # Enable CUPS to print documents.
    # printing.enable = true;

    # swayosd.enable = true;

    tailscale.enable = true;

    blueman.enable = true;

    logind = {
      lidSwitch = "ignore";
      extraConfig = ''
        HandlePowerKey=suspend
      '';
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      # media-session.enable = true;
    };

    # xserver = {
    #   # Enable the X11 windowing system.
    #   enable = true;
    #
    #   # Enable the GNOME Desktop Environment.
    #   displayManager.gdm.enable = true;
    #   desktopManager.gnome.enable = true
    #
    #   # Enable KDE.
    #   displayManager.sddm.enable = true;
    #   desktopManager.plasma5.enable = true
    #
    #   # Enable touchpad support (enabled default in most desktopManager).
    #   libinput.enable = true;
    #
    #   # Configure keymap in X11
    #   layout = "us";
    #   xkbVariant = "";
    # };

    udev.packages = [ pkgs.swayosd ];
  };

  # programs.nix-ld = {
  #   enable = true;
  #   # libraries = options.programs.nix-ld.libraries.default ++ (with pkgs; [ yourlibrary ]);
  #   libraries = options.programs.nix-ld.libraries.default;
  # };
  # environment.variables = {
  #   NIX_LD = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
  # };

  programs = {
    git.enable = true;
    neovim.enable = true;
    hyprland.enable = true;
    zsh.enable = true;
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
    pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
      polkit-1.u2fAuth = true;
    };
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

  system = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "23.11"; # Did you read the comment?
    autoUpgrade = {
      enable = true;
      # allowReboot = true;
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
}
