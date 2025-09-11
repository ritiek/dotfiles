{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./home
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/wifi.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/usbipd.nix
    ./../../modules/restic-server.nix
  ];

  sops.secrets."ritiek.hashedpassword".neededForUsers = true;

  networking.hostName = lib.mkForce "keyberry";
  time.timeZone = lib.mkDefault "Asia/Kolkata";

  nixpkgs.config.allowUnfree = true;

  boot = {
    supportedFilesystems = [ "ntfs" ];

    # Raspberry Pi kernel for better GPIO support
    kernelPackages = lib.mkForce pkgs.linuxPackages_rpi4;

    # GPIO and device tree related kernel modules
    kernelModules = [
      "libcomposite"
      "cma=2048M"
      "pwm_bcm2835"
      "w1-gpio"
      "i2c-dev"
      "spi-dev"
    ];

    # Kernel parameters for GPIO access
    kernelParams = [
      "iomem=relaxed"
      "strict-devmem=0"
    ];
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [{
      hostName = "pilab.lion-zebra.ts.net";
      system = "aarch64-linux";
      # system = pkgs.stdenv.hostPlatform;
      # systems = [ "aarch64-linux" ];
      # protocol = "ssh-ng";
      protocol = "ssh";
      sshUser = "ritiek";
      maxJobs = 8;
      speedFactor = 5;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      # mandatoryFeatures = [ ];
    }];
    # settings.builders-use-substitutes = true;
  };

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    # users.restic.extraGroups = [
    #   "storage"
    #   "disk"
    # ];

    users.ritiek = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."ritiek.hashedpassword".path;
      extraGroups = [
        "wheel"
        "video"
        "input"
        "render"
        "gpio"
        "i2c"
        "spi"
        "dialout"
      ];
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
      ];
      packages = [
        inputs.home-manager.packages.${pkgs.system}.default
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    dconf
    # mesa
    # libGL

    # GPIO and hardware access tools
    libgpiod
    lgpio
    pigpio
    gpio-utils
    i2c-tools
    python3Packages.pigpio
    python3Packages.gpiozero
    python3Packages.lgpio
  ];

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
    # gnupg.agent.enable = true;
  };

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      wheelNeedsPassword = false;
    };
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
    ];
  };

  services = {
    openssh = {
      enable = true;
      startWhenNeeded = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };

    tailscale.extraUpFlags = lib.mkAfter [
      "--advertise-routes=192.168.1.0/24"
    ];

    pulseaudio.enable = false;

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

    uptime-kuma = {
      enable = true;
      appriseSupport = false;
      settings = {
        HOST = "0.0.0.0";
        PORT = "3001";
        # FIXME: This results in a permission error during nixos-rebuild.
        # DATA_DIR = lib.mkForce "/root/uptime-kuma";
      };
    };

    pi400kb.enable = true;
  };

  # Hardware configuration for GPIO support
  hardware = {
    deviceTree = {
      enable = true;
      overlays = [
        {
          name = "pwm-2chan";
          dtboFile = "${pkgs.device-tree_rpi.overlays}/pwm-2chan.dtbo";
        }
        {
          name = "w1-gpio";
          dtboFile = "${pkgs.device-tree_rpi.overlays}/w1-gpio.dtbo";
        }
      ];
    };
    i2c.enable = true;
    # SPI is enabled via kernel modules, no hardware.spi option exists
  };

  # Users need to be in gpio group for GPIO access
  users.groups.gpio = {};
  users.groups.i2c = {};
  users.groups.spi = {};

  # Udev rules for GPIO device permissions
  services.udev.extraRules = ''
    SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio; chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 770 /sys/devices/virtual/gpio || true'"
    SUBSYSTEM=="pwm*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/pwm && chmod -R 770 /sys/class/pwm || true'"
    KERNEL=="spidev*", GROUP="spi", MODE="0664"
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0664"
    KERNEL=="gpiochip*", GROUP="gpio", MODE="0664"
    KERNEL=="gpio*", GROUP="gpio", MODE="0664"
  '';

  powerManagement.cpuFreqGovernor = "performance";
  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };

  boot.tmp = {
    # Not using tmpfs as it causes nixos-generators to eat
    # RAM like a furious pete.
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.settings.Manager.RuntimeWatchdogSec = "360s";

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
