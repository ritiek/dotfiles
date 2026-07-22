# alcove - Radxa Cubie A7S (Allwinner A733 / sun60iw2).
# See RADXA_CUBIE_A7S_NIXOS_PLAN.md in the NIXOS_PORTS repo for the full
# bring-up history (custom kernel, vendor U-Boot blobs, out-of-tree
# AIC8800D80 USB WiFi driver). This file follows the same fleet
# conventions as machines/radrubble and machines/chocomelt (sops secrets,
# distributed builds, ritiek/rnixbld users) - see hw-config.nix for the
# board-specific bootloader/kernel/WiFi wiring.
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./home
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./services/attic.nix
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/attic-watch-store.nix
    ./../../modules/wifi.nix
    ./../../modules/usbipd.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/netbird.nix
  ];

  sops.secrets = {
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
  };

  networking.hostName = "alcove";
  time.timeZone = "Asia/Kolkata";

  # Needed for the unfree vendor U-Boot blobs (see hw-config.nix).
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

      git
      vim
      htop
      iproute2
      curl
      ethtool
      # Added during bring-up to debug the onboard Ethernet PHY over MDIO
      # (now resolved - it was a bad cable, see plan doc). Harmless/cheap to
      # keep for any future diagnostics; remove if a leaner image is wanted.
      mdio-tools
      phytool
    ];
  };

  services = {
    openssh = {
      enable = true;
      startWhenNeeded = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };
    timesyncd.enable = true;
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

  boot.binfmt.emulatedSystems = [ "armv6l-linux" ];

  # nixpkgs' stdenv bootstrap gates building the armv6l-linux bootstrap-tools
  # (and the rest of the armv6l stdenv bootstrap chain) behind this custom
  # system-feature flag - "armv6kz" refers to the ARMv6KZ ISA variant of the
  # Raspberry Pi Zero W's ARM1176JZF-S core (minimachine's target hardware).
  # Without this, even with QEMU emulation registered above
  # (boot.binfmt.emulatedSystems), Nix refuses to build these derivations
  # locally with "Reason: missing system features, Required features:
  # {gccarch-armv6kz}" - it's an explicit opt-in gate, not automatically
  # implied by binfmt emulation alone.
  nix.settings.system-features = [ "gccarch-armv6kz" ];

  systemd.settings.Manager.RuntimeWatchdogSec = "360s";

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "25.11";
}
