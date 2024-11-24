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
    "/media" = {
      device = "/dev/disk/by-label/HOMELAB_BACKUP";
      fsType = "ext4";
      autoResize = true;
      options = [
        "noatime"
        "noauto"
        # "uid=${toString config.ids.uids.restic}"
        # "gid=${toString config.ids.gids.restic}"
        # "forceuid"
        # "forcegid"
        # "dmask=007"
        # "fmask=117"
        "nofail"
        # "x-systemd.before=local-fs.target"
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
