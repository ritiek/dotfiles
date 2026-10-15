{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
  ];
  boot.kernelModules = [ ];
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # nixpkgs dropped linux_rpi*; nixos-hardware now carries the kernel.
  boot.kernelPackages = pkgs.linuxPackagesFor
    (pkgs.callPackage "${inputs.nixos-hardware}/raspberry-pi/common/kernel.nix" { rpiVersion = 4; });

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
  };
  # swapDevices = [{
  #   device = "/var/lib/swapfile";
  #   size = 1*1024;  # 1GB
  # }];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
