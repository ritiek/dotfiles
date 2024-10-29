{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./minimal.nix
    ./home.nix
    ./services.nix
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./../../common/sops.nix
    ./../../common/tailscale.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.persistence."/nix/persist/system" = {
    directories = [
      "/var/lib/tailscale"
    ];
    # files = [
    #   "/var/lib/tailscale/tailscaled.state"
    # ];
  };

  users.defaultUserShell = pkgs.zsh;
  users.users.root.packages = [
    inputs.home-manager.packages.${pkgs.system}.default
  ];

  # environment.systemPackages = with pkgs; [
  #   iptables
  # ];

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
  };

  services = {
    openssh = {
      openFirewall = true; 
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.firewall.enable = true;
}
