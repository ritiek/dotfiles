{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "clawsiecats";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # boot.loader.grub.enable = true;
  # # boot.loader.grub.device = "nodev";
  # boot.loader.grub.device = "/dev/sdb";
  # boot.loader.grub.useOSProber = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # # boot.loader.efi.efiSysMountPoint = "/boot";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

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

  disko.devices.nodev = {
    "/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=1G"
      ];
    };
  };

  users.users.root = {
    hashedPassword = "$y$j9T$G4lGrOLFl1C/ey0IBYH70.$khzzf0.LLFA4q4TCmjT6OW/WHYYBEE7XFIxgP2jg9p7";
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"

      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
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
