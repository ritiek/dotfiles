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
  # vkms: pure software/virtual DRM output, used so niri/Sunshine has a display to
  # capture without needing the passthrough iGPU to do real scanout (which has been
  # the trigger for every host crash this session). Rendering stays pinned to the
  # passthrough iGPU's renderD128 via niri's render-drm-device option.
  boot.kernelModules = [ "vkms" ];
  boot.extraModprobeConfig = ''
    options vkms enable_cursor=1
  '';
  boot.extraModulePackages = [ ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
