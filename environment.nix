{ config, lib, pkgs, modulesPath, ... }:

{
  time.timeZone = "Asia/Kolkata";

  networking.hostName = "nixin"; # Define your hostname.

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.kernelModules = [ "kvm-intel" "vhci-hcd" ];
}
