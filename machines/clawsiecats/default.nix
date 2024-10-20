{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./minimal.nix
    ./home
    ./services.nix
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
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

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "tailscale.authkey" = {};
    };
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
    tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."tailscale.authkey".path;
      useRoutingFeatures = "both";
      extraUpFlags = [
        "--advertise-exit-node"
      ];
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.firewall.enable = true;
}
