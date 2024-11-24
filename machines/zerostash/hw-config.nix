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
    restic-backup = {
      mountPoint = "/RESTIC_BACKUP";
      device = "/dev/disk/by-label/RESTIC_BACKUP";
      fsType = "ext4";
      label = "RESTIC_BACKUP";
      autoResize = true;
      options = [
        "noatime"
        "noauto"
        "nofail"
        "x-systemd.automount"
        "x-systemd.mount-timeout=5s"
      ];
    };
  };
  # swapDevices = [{
  #   device = "/var/lib/swapfile";
  #   size = 1*1024;  # 1GB
  # }];
}
