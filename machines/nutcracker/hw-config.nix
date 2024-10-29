{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      autoResize = true;
      options = [ "noatime" ];
    };
  };

  # disko.devices.disk.${config.networking.hostName} = {
  #   device = "/dev/disk/by-label/NIXOS_SD";
  #   content = {
  #     type = "gpt";
  #     partitions = {
  #       # boot = {
  #       #   size = "2M";
  #       #   type = "EF02";
  #       # };
  #       esp = {
  #         size = "200M";
  #         type = "EF00";
  #         content = {
  #           type = "filesystem";
  #           format = "vfat";
  #           mountpoint = "/boot";
  #         };
  #       };
  #       nix = {
  #         end = "-3G";
  #         content = {
  #           type = "filesystem";
  #           format = "btrfs";
  #           mountpoint = "/nix";
  #           mountOptions = [
  #             "noatime"
  #             "compress-force=zstd:3"
  #           ];
  #           extraArgs = [ "-Lnix" ];
  #         };
  #       };
  #       plain-swap = {
  #         size = "100%";
  #         content = {
  #           type = "swap";
  #           discardPolicy = "both";
  #           resumeDevice = true;
  #         };
  #       };
  #     };
  #   };
  # };
  #
  # disko.devices.nodev = {
  #   "/" = {
  #     fsType = "tmpfs";
  #     mountOptions = [
  #       "size=2G"
  #       "mode=755"
  #     ];
  #   };
  # };
}
