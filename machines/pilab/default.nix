{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./home
    ./services-paths.nix
    ./services/restic.nix
    ./services/lsyncd.nix
    ./services/home-assistant
    # ./services/paperless-ngx.nix
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/wifi.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/attic.nix
    ./../../modules/usbipd.nix
    # Generated using:
    # $ compose2nix --env_files=stack.env --include_env_files=true --check_systemd_mounts=true --auto_start=false --remove_volumes=true --runtime=docker
    ./compose/pihole
    ./compose/homepage.nix
    # ./compose/dashy.nix
    ./compose/immich
    ./compose/uptime-kuma.nix
    ./compose/tubearchivist
    ./compose/paperless-ngx
    ./compose/forgejo
    ./compose/vaultwarden
    ./compose/navidrome.nix
    ./compose/memos.nix
    ./compose/syncthing.nix
    ./compose/miniflux
    ./compose/gotify.nix
    # ./compose/shiori
    ./compose/homebox.nix
    ./compose/conduwuit
    ./compose/grocy
    ./compose/changedetection
    ./compose/frigate
    ./compose/habitica
    ./compose/ollama-webui
    ./compose/pwpush
    ./compose/dawarich
    ./compose/rustdesk.nix
    ./compose/simplexchat
    # ./compose/filebrowser-quantum.nix
    ./compose/copyparty.nix
    ./compose/nitter.nix
    ./compose/mealie
    ./compose/karakeep
    ./compose/n8n
    ./compose/transmission
    ./compose/qbittorrent.nix
    ./compose/jellyfin.nix
    ./compose/radarr.nix
    ./compose/sonarr.nix
    ./compose/bazarr.nix
    ./compose/prowlarr.nix
    ./compose/jellyseerr.nix
    ./compose/glances.nix
    ./compose/calibre-web-automated
    ./compose/calibre-web-automated-book-downloader.nix
    # ./compose/kopia
  ];

  sops.secrets = {
    # "jitsi.htpasswd" = {
    #   owner = "nginx";
    # };
    "syncplay.password" = {};
  };

  nixpkgs.config.allowUnfree = false;

  networking.hostName = "pilab";
  time.timeZone = "Asia/Kolkata";

  services.tailscale.extraUpFlags = lib.mkAfter [
    "--accept-routes"
    "--accept-dns=false"
  ];

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;
    groups.i2c = {};
    groups.gpio = {};

    users.ritiek = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "i2c"
        "gpio"
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

    users.immi = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      packages = [
        inputs.home-manager.packages.${pkgs.system}.default
      ];
    };
  };

  # nixpkgs.config.permittedInsecurePackages = [
  #   "jitsi-meet-1.0.8043"
  # ];

  services = {
    udev.extraRules = ''
      KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
      SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
    '';
    
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

    # NOTE: This doesn't seem to work as is since Jitsi requires HTTPS.
    # jitsi-meet = {
    #   enable = true;
    #   hostName = "pilab.lion-zebra.ts.net";
    #   nginx.enable = false;
    #   config = {
    #     enableInsecureRoomNameWarning = true;
    #     fileRecordingsEnabled = false;
    #     liveStreamingEnabled = false;
    #     prejoinPageEnabled = true;
    #   };
    #   interfaceConfig = {
    #     SHOW_JITSI_WATERMARK = false;
    #     SHOW_WATERMARK_FOR_GUESTS = false;
    #   };
    # };
    #
    # jitsi-videobridge.openFirewall = true;

    syncplay = {
      enable = true;
      passwordFile = config.sops.secrets."syncplay.password".path;
    };
  };

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
    # gnupg.agent.enable = true;
  };

  virtualisation = {
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      autoPrune.enable = true;
      # Expand docker's pool of available subnets by creating
      # smaller subnets.
      # At the time of writing this - docker defaults this to
      # 32, which means it can allocate subnets to a maximum
      # of 32 docker compose swarms at the same time.
      daemon.settings = {
        bip = "10.255.0.1/24";
        fixed-cidr = "10.255.0.0/24";
        default-address-pools = [
          { base = "10.240.0.0/12"; size = 24; }    # ~4096 /24 networks
          { base = "172.20.0.0/16"; size = 24; }    # +256 /24 networks
        ];
        mtu = 9000;
      };
    };
  };

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      wheelNeedsPassword = lib.mkDefault false;
    };
  };

  # NOTE: For modes supported by the CPU, run:
  # $ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
  powerManagement.cpuFreqGovernor = "conservative";

  zramSwap = {
    enable = true;
    memoryPercent = 275;
  };

  networking.localCommands = ''
    # Prioritize default route over Tailscale route for default gateway.
    ip rule add to 192.168.2.0/24 priority 2500 lookup main
  '';

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
