{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./home
    ./minimal.nix
    ./services.nix
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/tailscale-controlplane.nix
  ];

  sops.secrets = {
    "ritiek.hashedpassword".neededForUsers = true;
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "mishy.lion-zebra.ts.net";
        system = pkgs.stdenv.hostPlatform.system;
        protocol = "ssh-ng";
        sshUser = "rnixbld";
        sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUl3R0phWjZFTkdoUk9EKzZQdGxOM29Md1NRVkJBSU9PNmFLTjdqYUJWenYK";
        maxJobs = 8;
        speedFactor = 8;
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

  environment.persistence."/nix/persist/system" = {
    directories = [
      "/var/lib/tailscale"
    ];
    # files = [
    #   "/var/lib/tailscale/tailscaled.state"
    # ];
  };

  nixpkgs.overlays = [
    inputs.headplane.overlays.default

    # Bun baseline overlay for CPUs without AVX2
    (final: prev: {
      bun = prev.bun.overrideAttrs (oldAttrs: {
        src = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${oldAttrs.version}/bun-linux-x64-baseline.zip";
          hash = "sha256-f/CaSlGeggbWDXt2MHLL82Qvg3BpAWVYbTA/ryFpIXI=";
        };
      });
    })
  ];

  users.defaultUserShell = pkgs.zsh;
  users.users.root.openssh.authorizedKeys.keys = [ ];

  users = {
    users.ritiek = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."ritiek.hashedpassword".path;
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

        # Deploy key
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDM4K9v5v6sGycejZDxf6fHpiLkt7dxuo/mINCE011y2"
      ];
      packages = with pkgs; [
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

  # environment.systemPackages = with pkgs; [
  #   iptables
  # ];

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
    nix-ld = {
      enable = true;
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
  };

  services = {
    openssh = {
      openFirewall = true; 
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };
  };

  # virtualisation.docker.enable = true;

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.firewall.enable = true;
}
