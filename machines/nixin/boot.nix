{
  # Force Wayland on all apps.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    # WAYLAND_DISPLAY = "wayland-1";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.kernelModules = [ "kvm-intel" "vhci-hcd" ];
}
