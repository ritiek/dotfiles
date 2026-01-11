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
  ];

  sops.secrets = {
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
  };

  networking.hostName = "radrubble";
  time.timeZone = "Asia/Kolkata";

  nixpkgs.config.allowUnfree = true;

  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "pilab.lion-zebra.ts.net";
        system = pkgs.stdenv.hostPlatform.system;
        protocol = "ssh-ng";
        sshUser = "rnixbld";
        sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSVBCT1IvaGthQzM4YlhZcGZ5RURXaUJMSUF6TnJ2WldUS2ZDb3lDOHNVMFEK";
        maxJobs = 4;
        speedFactor = 3;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
      {
        hostName = "keyberry.lion-zebra.ts.net";
        system = pkgs.stdenv.hostPlatform.system;
        protocol = "ssh-ng";
        sshUser = "rnixbld";
        sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU93TTJ6N0JENWhrbGJSZURkT056OStOQUh5TVdtMmY1dHhKMlhDZTA2dXUK";
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
      {
        hostName = "zerostash.lion-zebra.ts.net";
        system = pkgs.stdenv.hostPlatform.system;
        protocol = "ssh-ng";
        sshUser = "rnixbld";
        sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU0rdjFsZVJwVGR5SGxNSlFsWStLZ1NnUHVSZlUwRzNWdG1hQ0pOeGpBbWwK";
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
    ];
  };

  boot.supportedFilesystems = [ "ntfs" ];

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    # users.restic.extraGroups = [
    #   "storage"
    #   "disk"
    # ];

    users.ritiek = {
      isNormalUser = true;
      password = "ff";
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
        inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

    users.rnixbld = {
      isSystemUser = true;
      # group = "nixbld";
      group = "users";
      # gid = 30000;
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
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPlUpYpBOffFgrMAViDxiTCrVCRP6wQIFWd7/KiNkV2"
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
      wheelNeedsPassword = false;
    };
  };

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
