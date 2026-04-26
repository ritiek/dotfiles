{ lib, config, pkgs, inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.matthew-hardware.nixosModules.rpi-zero-w
    inputs.matthew-hardware.nixosModules.rpi-zero-w-disko
  ];

  nixpkgs.overlays = [
    (self: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  boot.kernelPatches = [
    {
      name = "config-enable-zboot";
      patch = null;
      structuredExtraConfig = {
        EFI = lib.mkForce lib.kernel.yes;
        EFI_ZBOOT = lib.mkForce lib.kernel.yes;
        EFIVAR_FS = lib.mkForce lib.kernel.yes;
      };
    }
  ];

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.root = "gpt-auto";
  boot.initrd.systemd.tpm2.enable = false;

  boot.loader = {
    generic-extlinux-compatible.enable = lib.mkForce false;
    grub.enable = lib.mkForce false;
  };

  hardware.rpi-zero-w = {
    enable = true;
    zealous = true;
    image = {
      configTxt = ''
        [pi0]
        kernel=u-boot.bin
        disable_overscan=1
        boot_delay=1

        [all]
        dtparam=sd_overclock=25
        dtparam=sd_force_pio=on
        enable_uart=1
        avoid_warnings=1
      '';
      repart = {
        enable = true;
        format = "btrfs";
      };
    };
  };
}
