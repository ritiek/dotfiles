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

  sops.secrets = {
    "ritiek.hashedpassword".neededForUsers = true;
    # "cameras.porch.rtsp" = {};
  };

  networking.hostName = lib.mkForce "keyberry";
  time.timeZone = lib.mkDefault "Asia/Kolkata";

  nixpkgs.config.allowUnfree = false;

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
    settings.sandbox = false;
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
        inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    dconf
    # mesa
    # libGL

    libgpiod
    i2c-tools
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

    # frigate = {
    #   enable = true;
    #   # Setting this to false as reading camera URLs from environment is flagged as invalid
    #   # by this option.
    #   checkConfig = false;
    #   hostname = "keyberry.lion-zebra.ts.net";
    #   settings = {
    #     version = "0.16-0";
    #     auth.enabled = false;
    #     # auth.reset_admin_password = true;
    #
    #     mqtt = {
    #       enabled = false;
    #     };
    #
    #     go2rtc = {
    #       streams = {
    #         porch = [
    #           "{FRIGATE_RTSP_SUBTYPE1}"
    #           "ffmpeg:camera.porch#audio=aac"
    #         ];
    #       };
    #     };
    #
    #     detectors = {
    #       cpu1 = {
    #         type = "cpu";
    #         num_threads = 3;
    #       };
    #     };
    #
    #     cameras = {
    #       porch = {
    #         ffmpeg = {
    #           input_args = "preset-rtsp-restream";
    #           output_args = {
    #             record = "preset-record-generic-audio-aac";
    #           };
    #           inputs = [
    #             {
    #               path = "{FRIGATE_RTSP_SUBTYPE0}";
    #               roles = [ "record" ];
    #             }
    #             {
    #               path = "{FRIGATE_RTSP_SUBTYPE1}";
    #               roles = [ "audio" "detect" ];
    #             }
    #           ];
    #         };
    #         detect = {
    #           enabled = true;
    #           width = 1280;
    #           height = 720;
    #         };
    #         objects = {
    #           track = [ "person" ];
    #           filters.person.threshold = 0.7;
    #         };
    #       };
    #     };
    #
    #     audio.enabled = true;
    #     record.enabled = true;
    #     detect.enabled = true;
    #     ui.timezone = "Asia/Kolkata";
    #   };
    # };

  };

  # systemd.services.frigate.serviceConfig = {
  #   EnvironmentFile = config.sops.templates."frigate-env".path;
  # };
  #
  # sops.templates."frigate-env" = {
  #   content = ''
  #     FRIGATE_RTSP_SUBTYPE0=${config.sops.placeholder."cameras.porch.rtsp"}&subtype=0
  #     FRIGATE_RTSP_SUBTYPE1=${config.sops.placeholder."cameras.porch.rtsp"}&subtype=1
  #   '';
  #   mode = "0400";
  #   owner = config.users.users.frigate.name;
  # };

  powerManagement.cpuFreqGovernor = "conservative";
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
