{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" "virtio-pci" "virtio_net" ];
  boot.initrd.kernelModules = [ ];

  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      hostKeys = [
        "/boot/ssh_host_ed25519_key"
      ];
    };
    postCommands = ''
      echo 'cryptsetup-askpass' >> /root/.profile
    '';
  };

  # boot.loader.grub = {
  #   enable = true;
  #   device = "/dev/vda";
  #   efiSupport = true;
  # };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  disko.devices.disk.clawsiecats = {
    device = lib.mkDefault "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        # boot = {
        #   size = "2M";
        #   type = "EF02";
        # };
        ESP = {
          size = "200M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        luks = {
          end = "-3G";
          content = {
            type = "luks";
            name = "cryptnix";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              mountpoint = "/nix";
              mountOptions = [
                "noatime"
                "compress-force=zstd:3"
              ];
            };
          };
        };
        encryptedSwap = {
          size = "100%";
          content = {
            type = "swap";
            randomEncryption = true;
            priority = 100;
          };
        };
      };
    };
  };

  disko.devices.nodev = {
    "/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=2G"
        "mode=755"
      ];
    };
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  virtualisation.hypervGuest.enable = true;
}
