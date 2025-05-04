# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, modulesPath, options, inputs, ... }:

{
  time.timeZone = "Asia/Kolkata";
  networking.hostName = "mishy";

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

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.nix-index-database.nixosModules.nix-index
    inputs.sops-nix.nixosModules.sops
    ./home
    ./graphics.nix
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/ssh.nix
    ./../../modules/yubico-pam.nix
    ./../../modules/usbip.nix
    # inputs.shabitica-nix.nixosModules."x86_64-linux".default
  ];

  # shabitica = {
  #   adminMailAddress = "ritiekmalhotra123@gmail.com";
  #   senderMailAddress = "ritiekmalhotra123@gmail.com";
  # };

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
    users.root.password = "";
    users.ritiek = {
      isNormalUser = true;
      description = "Ritiek Malhotra";
      password = "";
      extraGroups = [
        # "networkmanager"
        "wheel"
        "video"
        "audio"
        "input"
        # "dialout"
        "polkituser"
        # "users"
        "plugdev"
        "kvm"
        "adbusers"
      ];
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
      ];
      packages = [
        inputs.home-manager.packages.${pkgs.system}.default
      ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  environment = {
    systemPackages = with pkgs; [
      # Flakes use Git to pull dependencies from data sources 
      wget
      curl
      screen
      swayosd
      brightnessctl

      # Superseded by programs.ssh.startAgent = true;
      # keychain

      btop
      gparted
      xclip
      xorg.xhost
      # helix
      parallel
      libarchive
      # android-tools

      xorg.xeyes
      netdiscover
      usbutils
      libnotify
      lshw
      pv
      glxinfo
      sof-firmware
      intel-gpu-tools
      cpulimit
      linuxPackages.usbip
      # docker-compose

      xdg-utils
      xdg-desktop-portal
      xdg-desktop-portal-hyprland

      inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    ];

    # variables.EDITOR = "nvim";
  };

  virtualisation = {
    docker.enable = true;
    waydroid.enable = true;
  };

  systemd = {
    services = {
      avahi = {
        enable = true;
      };
      swayosd-libinput-backend = {
        description = "swayosd-libinput-backend";
        enable = true;
        path = with pkgs; [
          coreutils
          swayosd
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
  };

  # Enable sound with pipewire.
  # sound.enable = true;

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    openssh = {
      enable = true;
      startWhenNeeded = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    pulseaudio.enable = false;
    dbus.enable = true;
    # Smartcard
    pcscd = {
      enable = true;
      # plugins = with pkgs.pcsc; [
      #   pcsc-safenet
      # ];
    };

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
      alsa = {
        enable = true;
        support32Bit = true;
      };
      wireplumber.enable = true;
      pulse.enable = true;
      jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
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

    udev = {
      packages = with pkgs; [
        swayosd
        # android-tools
        # yubikey-personalization
      ];
      extraRules = ''
      #   # FIXME: Try getting ADB to work non-root users.
      #   SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", ATTR{idProduct}=="2e81", MODE="0666", GROUP="plugdev"
      #   # FIXME: Auto-lock screen on unplugging Yubikey.
      #   ACTION=="remove",\
      #    ENV{ID_BUS}=="usb",\
      #    ENV{ID_MODEL_ID}=="0402",\
      #    ENV{ID_VENDOR_ID}=="1050",\
      #    ENV{ID_VENDOR}=="Yubico",\
      #    RUN+="${pkgs.libnotify}/bin/notify-send locking"
      '';
      # # RUN+="${pkgs.procps} hyprlock || ${pkgs.unstable.hyprlock}/bin/hyprlock"
    };

    # Allows `calibre` to detect attached Kindle devices.
    udisks2.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    wlr.enable = true;
    config = {
      common.default = [ "hyprland" ];
      hyprland.default = [ "gtk" "hyprland" ];
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      # xdg-desktop-portal-hyprland
      # xdg-desktop-portal-wlr
    ];
    # gtkUsePortal = true;
  };

  programs = {
    nix-index-database.comma.enable = true;
    ssh.startAgent = true;
    gnupg.agent = {
      enable = true;
      # pinentryPackage = lib.mkForce pkgs.pinentry-qt;
      # pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
      # enableSSHSupport = true;
    };

    git.enable = true;
    neovim.enable = true;
    hyprland = {
      enable = true;
      # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      # portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
      xwayland.enable = true;
    };
    zsh.enable = true;

    nix-ld = {
      enable = true;
      package = pkgs.nix-ld-rs;
      libraries = with pkgs; [
        # Bombsquad Game.
        # Now installing these packages using Lutris in home-manager.
        # python312
        # SDL2
        # libvorbis
        # libGL
        # openal
        # stdenv.cc.cc
      ];
    };

    # Gamescope currently doesn't work:
    # https://github.com/NixOS/nixpkgs/issues/292620
    # gamescope = {
    #   enable = true;
    #   capSysNice = true;
    # };
    steam = {
      enable = true;
      # gamescopeSession.enable = true;
    };
    gamemode = {
      enable = true;
      enableRenice = true;
    };

    yubikey-touch-detector = {
      enable = true;
      libnotify = true;
    };
  };

  security = {
    sudo.enable = false;
    sudo-rs.enable = true;

    rtkit.enable = true;
    polkit.enable = true;
  };

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      cantarell-fonts
      material-design-icons
      noto-fonts

      nerd-fonts.fantasque-sans-mono
      nerd-fonts.inconsolata-go
      nerd-fonts.jetbrains-mono
      # nerd-fonts.fira-code
      # nerd-fonts.noto
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
      enable = false;
      channel = "https://nixos.org/channels/nixos-unstable";
      allowReboot = false;
    };
  };

  # powerManagement.cpuFreqGovernor = "ondemand";
  powerManagement.cpuFreqGovernor = "performance";
  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.supportedFilesystems = [ "ntfs" ];
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.watchdog.runtimeTime = "360s";

  # Force Wayland on all apps.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    # WAYLAND_DISPLAY = "wayland-1";
  };
}
