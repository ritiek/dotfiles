{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
  ];

  disko.devices.disk.clawsiecats = {
    device = lib.mkDefault "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "200M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        nix = {
          end = "-3G";
          content = {
            type = "filesystem";
            format = "btrfs";
            mountpoint = "/nix";
            mountOptions = [
              "compress-force=zstd:3"
            ];
          };
        };
        plainSwap = {
          size = "100%";
          content = {
            type = "swap";
            discardPolicy = "both";
            resumeDevice = true;
          };
        };
      };
    };
  };
  disko.devices.disk.impermanence = {
    "/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=1G"
      ];
    };
  };

  environment.persistence."/nix/persist/system" = {
    enable = true; 
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/ssh"
      "/var/log"
      "/var/lib/acme"
      "/var/lib/jitsi-meet"
      "/var/lib/prosody"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
    ];
    users.root = {
      home = "/root";
      files = [
        ".age-key"
      ];
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "clawsiecats";

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  time.timeZone = "Asia/Kolkata";
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

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

  users = {
    defaultUserShell = pkgs.zsh;
    users.root.openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
    ];
  };

  # environment.systemPackages = with pkgs; [
  #   iptables
  # ];

  programs = {
    zsh.enable = true;
  };

  services = {
    btrfs.autoScrub.enable = true;
    openssh = {
      enable = true;
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

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
