{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./home
    ./services/restic.nix
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
    ./compose/shiori
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
    # ./compose/kopia
  ];

  networking.hostName = "pilab";
  time.timeZone = "Asia/Kolkata";

  boot.supportedFilesystems = [ "ntfs" ];

  services.tailscale.extraUpFlags = lib.mkAfter [
    "--accept-routes"
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
      wheelNeedsPassword = lib.mkDefault false;
    };
  };

  powerManagement.cpuFreqGovernor = "performance";
  zramSwap = {
    enable = true;
    memoryPercent = 200;
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

  systemd.watchdog.runtimeTime = "360s";

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
