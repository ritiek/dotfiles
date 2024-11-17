{ config, lib, pkgs, modulesPath, ... }:

{
  hardware.raspberry-pi."4".dwc2.enable = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelModules = [ "libcomposite" ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      autoResize = true;
      options = [ "noatime" ];
    };
  };
}
