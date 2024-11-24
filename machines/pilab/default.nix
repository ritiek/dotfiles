{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./home
    ./services/spotdl.nix
    ./hw-config.nix
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/wifi.nix
    ./../../modules/tailscale.nix
    # Generated using:
    # $ compose2nix --env_files=stack.env --include_env_files=true --check_systemd_mounts=true --auto_start=false --remove_volumes=true --runtime=docker
    ./compose/dashy.nix
    ./compose/pihole
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
    ./compose/shiori
    ./compose/homebox.nix
    ./compose/conduwuit
    ./compose/grocy
    ./compose/kopia
  ];

  sops.secrets = {
    "stashy.repository" = {};
    "stashy.password" = {};
    "zerostash.repository" = {};
    "zerostash.password" = {};
  };

  networking.hostName = "pilab";
  time.timeZone = "Asia/Kolkata";

  # Needed for building SD images.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  boot.supportedFilesystems = [ "ntfs" ];

  # Ref:
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#h
  systemd.tmpfiles.settings."10-homelab"."/media" = {
    d = {
      group = "root";
      mode = "0755";
      user = "root";
    };
    h.argument = "+i";
  };

  # Since I am the DNS!
  services.tailscale.extraUpFlags = [
    "--accept-dns=false"
  ];

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    users.ritiek = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
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

    restic.backups.stashy = {
      initialize = true;
      repositoryFile = config.sops.secrets."stashy.repository".path;
      passwordFile = config.sops.secrets."stashy.password".path;
      paths = [
        "/media/services/spotdl/English Mix"
      ];
      pruneOpts = [
        "--keep-hourly 18"
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
        "--keep-tag forever"
      ];
      # Remove any stale locks
      backupPrepareCommand = ''
        ${pkgs.restic}/bin/restic unlock || true
      '';
      timerConfig = {
        # Every 20 minutes
        OnCalendar = "*:0/20";
        Persistent = true;
      };
    };

    restic.backups.zerostash = {
      initialize = true;
      repositoryFile = config.sops.secrets."zerostash.repository".path;
      passwordFile = config.sops.secrets."zerostash.password".path;
      paths = [
        "/media/services/spotdl/English Mix"
      ];
      pruneOpts = [
        "--keep-hourly 18"
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
        "--keep-tag forever"
      ];
      backupPrepareCommand = ''
        ${pkgs.restic}/bin/restic unlock || true
      '';
      timerConfig = {
        OnCalendar = "*:0/20";
        Persistent = true;
      };
    };
  };

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

  powerManagement.cpuFreqGovernor = "performance";
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  boot.tmp = {
    # Not using tmpfs as it causes nixos-generators to eat
    # RAM like a furious pete.
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.watchdog.runtimeTime = "360s";

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
