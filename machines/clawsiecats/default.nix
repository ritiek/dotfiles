{ config, lib, pkgs, ... }:

{
  imports = [
    ./minimal.nix
    ./services.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [];
    age.keyFile = "/root/.age-key";
    secrets = {
      "tailscale.authkey" = {};
    };
  };

  users.defaultUserShell = pkgs.zsh;

  # environment.systemPackages = with pkgs; [
  #   iptables
  # ];

  programs = {
    zsh.enable = true;
  };

  services = {
    btrfs.autoScrub.enable = true;
    beesd.filesystems = {
      cryptnix = {
        spec = "ID=dm-name-cryptnix";
        hashTableSizeMB = 112;
        verbosity = "crit";
        extraOptions = [ "--loadavg-target" "5.0" ];
      };
    };
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

  powerManagement.cpuFreqGovernor = "performance";
  zramSwap.enable = true;

  boot.tmp = {
    useTmpfs = true;
    cleanOnBoot = true;
  };
}
