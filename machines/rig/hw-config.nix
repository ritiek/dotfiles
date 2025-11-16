{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e1bd680f-09e8-4a24-956c-bd3eda2fc577";
    fsType = "ext4";
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  # We're running in a dedicated Proxmox VM, so don't need osprober.
  # boot.loader.grub.useOSProber = true;

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "xhci_pci" "usbhid" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
