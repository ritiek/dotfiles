{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./home
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/attic-watch-store.nix
    ./../../modules/wifi.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/netbird.nix
    ./../../modules/usbipd.nix
  ];

  sops.secrets = {
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
  };

  networking.hostName = "switchboard";
  time.timeZone = "Asia/Kolkata";

  # TODO: Make adjustments and set this to false.
  nixpkgs.config.allowUnfree = true;

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

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
      group = "users";
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPlUpYpBOffFgrMAViDxiTCrVCRP6wQIFWd7/KiNkV2"
      ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      coreutils
      systemd
      dconf
      wget
      curl
      usbutils
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
  };

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
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
    useTmpfs = false;
    cleanOnBoot = true;
  };

  # NOTE: RuntimeWatchdogSec is set to "15s" by hardware.cubie-a5e.enable
  # (in hw-config.nix, via nixos-cubie-a5e's cubie-a5e.nix module) as part of
  # its reboot workaround for WIP TF-A (no PSCI SYSTEM_RESET support).
  # Not overridden here to avoid a conflicting-definition error.

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
