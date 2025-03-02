{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
  ];
  boot.kernelModules = [ ];
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;

  # Needed for building SD images.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      autoResize = true;
      options = [ "noatime" ];
    };
    restic-backup = {
      mountPoint = "/media/${config.fileSystems.restic-backup.label}";
      device = "/dev/disk/by-label/${config.fileSystems.restic-backup.label}";
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
