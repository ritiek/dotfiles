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
  ];

  users.defaultUserShell = pkgs.zsh;
  users.users.root.openssh.authorizedKeys.keys = [ ];

  users.users.ritiek = {
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

      # Deploy key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDM4K9v5v6sGycejZDxf6fHpiLkt7dxuo/mINCE011y2"
    ];
  };
  users.users.ritiek.packages = with pkgs; [
    inputs.home-manager.packages.${pkgs.system}.default
    deploy-rs
  ];

  # environment.systemPackages = with pkgs; [
  #   iptables
  # ];

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
    nix-ld = {
      enable = true;
      package = pkgs.nix-ld-rs;
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
