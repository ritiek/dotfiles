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
  # linux-headers >= 7.3 (the 2026-11-22 nixpkgs bump) use __u128 in the arm64
  # UAPI headers; this rpi kernel tree (6.18.50) lacks the matching tools/
  # typedef and fails building tools/bpf/resolve_btfids. Their kernel.nix
  # hard-sets kernelPatches (boot.kernelPatches would be ignored), so append
  # nixpkgs' tools_128bit_types backport to the derivation's patches.
  # shortcut: drop once nixos-hardware ships the fix.
  boot.kernelPackages = pkgs.linuxPackagesFor
    (
      (pkgs.callPackage "${inputs.nixos-hardware}/raspberry-pi/common/kernel.nix" { rpiVersion = 4; }).overrideAttrs
        (old: { patches = (old.patches or [ ]) ++ [ pkgs.kernelPatches.tools_128bit_types.patch ]; })
    );

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
