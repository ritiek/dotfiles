# FIXME: Doesn't boot after installation for some reason.

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
      authorizedKeys = config.users.users.ritiek.openssh.authorizedKeys.keys;
    };
    postCommands = ''
      echo 'cryptsetup-askpass' >> /root/.profile
    '';
  };

  boot.loader.grub = {
    enable = true;
    # device = "/dev/vda";
    # NOTE: Disable `device` and enable `mirroredBoots`
    # when using tmpfs for /
    mirroredBoots = [
      {
        path = "/nix/boot";
        devices = [ "/dev/vda" ];
      }
    ];
    efiSupport = false;
    enableCryptodisk = true;
  };

  services = {
    btrfs.autoScrub.enable = true;
    beesd.filesystems = {
      cryptnix = {
        # spec = "ID=dm-name-nix";
        # spec = "PARTUUID=48a5b9f3-01";
        spec = "LABEL=cryptnix";
        hashTableSizeMB = 112;
        verbosity = "crit";
        extraOptions = [ "--loadavg-target" "1.5" ];
      };
    };
  };

  boot.initrd.luks.devices.cryptnix.preLVM = false;

  disko.devices.disk.clawsiecats = {
    device = lib.mkDefault "/dev/vda";
    type = "disk";
    content = {
      type = "table";
      format = "msdos";
      partitions = [
        {
          end = "-3G";
          part-type = "primary";
          # fs-type = "btrfs";
          # name = "cryptnix";
          bootable = true;
          content = {
            type = "luks";
            name = "cryptnix";
            extraOpenArgs = [ "--allow-discards" ];
            passwordFile = "/tmp/disk.key";
            content = {
              type = "filesystem";
              format = "btrfs";
              mountpoint = "/nix";
              mountOptions = [
                "noatime"
                "compress-force=zstd:3"
              ];
              extraArgs = [ "-Lcryptnix -f" ];
            };
          };
        }
        {
          start = "-3G";
          name = "swap";
          content = {
            type = "swap";
            discardPolicy = "both";
            resumeDevice = true;
          };
        }
      ];
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
