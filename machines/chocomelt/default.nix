{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./home
    ./services/nixarr.nix
    ./services/syncthing.nix
    ./services/frigate.nix
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/net-tuning.nix
    ./../../modules/netbird.nix
    ./../../modules/usbipd.nix
  ];

  sops.secrets = {
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
    "nixbuild2.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
  };

  networking.hostName = "chocomelt";
  time.timeZone = "Asia/Kolkata";

  # TODO: Make adjustments and set this to false.
  nixpkgs.config.allowUnfree = true;

  # nix = {
  #   distributedBuilds = true;
  #   buildMachines = [
  #     {
  #       hostName = "pilab.lion-zebra.ts.net";
  #       systems = [ pkgs.stdenv.hostPlatform.system ];
  #       protocol = "ssh-ng";
  #       sshUser = "rnixbld";
  #       sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
  #       publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSVBCT1IvaGthQzM4YlhZcGZ5RURXaUJMSUF6TnJ2WldUS2ZDb3lDOHNVMFEK";
  #       maxJobs = 4;
  #       speedFactor = 3;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #     {
  #       hostName = "keyberry.lion-zebra.ts.net";
  #       systems = [ pkgs.stdenv.hostPlatform.system ];
  #       protocol = "ssh-ng";
  #       sshUser = "rnixbld";
  #       sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
  #       publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU93TTJ6N0JENWhrbGJSZURkT056OStOQUh5TVdtMmY1dHhKMlhDZTA2dXUK";
  #       maxJobs = 4;
  #       speedFactor = 1;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #     {
  #       hostName = "zerostash.lion-zebra.ts.net";
  #       systems = [ pkgs.stdenv.hostPlatform.system ];
  #       protocol = "ssh-ng";
  #       sshUser = "rnixbld";
  #       sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
  #       publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU0rdjFsZVJwVGR5SGxNSlFsWStLZ1NnUHVSZlUwRzNWdG1hQ0pOeGpBbWwK";
  #       maxJobs = 4;
  #       speedFactor = 1;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #   ];
  # };

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

        # pilab's homelab-mount (Home Assistant OTP flow) pipes the LUKS
        # passphrase in on stdin; this key can only run mediaserver-start.
        ''restrict,command="/run/wrappers/bin/sudo /run/current-system/sw/bin/env PATH=/etc/profiles/per-user/ritiek/bin:/run/current-system/sw/bin:/run/wrappers/bin mediaserver-start" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClaWA6QKLNUcMz8dAC5bBZcIMFuHmfi9pxy1Y1Q554y root@pilab-homelab-mount''

        # Home Assistant's Homelab tile on radrubble: only reports the mount.
        ''restrict,command="/run/current-system/sw/bin/mountpoint -q /media/EVERYTHING_ELSE && echo true || echo false" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjFMSYJiGbMZ2mCmRsMfRuno7ima7EXLSUDZmuhmZt/ hass@radrubble''
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

  powerManagement.cpuFreqGovernor = "schedutil";
  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };
  # zram swap is cheap, SD-card reads aren't: prefer compressing idle anon
  # pages over evicting code pages (python/.NET libs) that get re-read from
  # the SD card, which is what thrashed frigate + the media stack together.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.settings.Manager.RuntimeWatchdogSec = "360s";

  # oomd kills a cgroup only after pressure stays above the limit for 2min
  # (e.g. a stuck transcode), well under RuntimeWatchdogSec.
  systemd.oomd = {
    enableRootSlice = true;
    enableSystemSlice = true;
    settings.OOM.DefaultMemoryPressureDurationSec = "2min";
  };

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
