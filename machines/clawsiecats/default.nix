{ config, lib, pkgs, ... }:

{
  imports = [
    ./minimal.nix
    ./services.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  time.timeZone = "Asia/Kolkata";

  sops = {
    defaultSopsFile = ./secrets.yaml;
    # age.sshKeyPaths = [
    #   "/etc/ssh/ssh_host_ed25519_key"
    # ];
    age.keyFile = "/root/.age-key";
    secrets = {
      "tailscale.authkey" = {};
    };
  };

  # Disable sudo as we've no non-root users.
  security.sudo.enable = false;

  users.defaultUserShell = pkgs.zsh;

  # environment.systemPackages = with pkgs; [
  #   iptables
  # ];

  programs = {
    zsh.enable = true;
  };

  services = {
    btrfs.autoScrub.enable = true;
    openssh = {
      openFirewall = true; 
      # startWhenNeeded = true;
      # settings = {
      #   PasswordAuthentication = false;
      # };
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
