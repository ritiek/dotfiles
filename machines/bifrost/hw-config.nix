{ lib, config, pkgs, inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.matthew-hardware.nixosModules.bcm2835-rpi-zero-w
  ];

  nixpkgs.overlays = [
    (self: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # Raspberry Pi Foundation's downstream kernel fork instead of mainline.
  # Mainline's brcmfmac/sdhci-iproc combo reproducibly times out on this
  # board's BCM43430 wifi chip after the firmware loads (every SDIO command
  # after preinit fails with -110/ETIMEDOUT) - this is a long-documented gap
  # between vanilla kernel.org brcmfmac and RPi's own out-of-tree SDIO
  # timing/retry patches. linux_rpi1 targets BCM2835/2836 (original Pi/Pi
  # Zero/Zero W) and, critically, renames its DTB output to
  # bcm2835-rpi-zero-w.dtb - the same name matthew-hardware's
  # hardware.deviceTree.name already expects - so no boot-flow changes
  # should be needed.
  # boot.kernelPackages = pkgs.linuxPackages_rpi1;

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
    {
      # The rpi defconfig enables these RP1-southbridge-specific drivers
      # (RP1 is Pi 5 hardware, not present on the Zero W) as modules, and
      # they fail to link on armv6l with undefined __aeabi_uldivmod/
      # __aeabi_ldivmod (a 64-bit division helper the kernel doesn't
      # export to modules). Disable them since they're unusable here anyway.
      name = "disable-unusable-rp1-modules";
      patch = null;
      structuredExtraConfig = {
        PWM_RP1 = lib.mkForce lib.kernel.no;
        VIDEO_RP1_CFE = lib.mkForce lib.kernel.no;
        I2C_DESIGNWARE_CORE = lib.mkForce lib.kernel.no;
      };
    }
  ];

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.root = "gpt-auto";
  boot.initrd.systemd.tpm2.enable = false;

  # USB gadget ethernet - allows SSH over the Zero W's data-capable micro-USB
  # port on first boot, no WiFi/network required. The mainline
  # bcm2835-rpi-zero-w.dts already sets dr_mode="otg" on the dwc2 controller
  # (via bcm283x-rpi-usb-otg.dtsi), so no dtoverlay is needed - loading
  # g_ether is sufficient, same pattern as alcove/radrubble/chocomelt/
  # switchboard. Connect to 10.0.0.6 from host (configure host side as
  # 10.0.0.1/24). Note: the Zero W has two micro-USB ports - use the one
  # labeled "USB", not "PWR IN". (bumped last octet from minimachine's
  # 10.0.0.5 to avoid an address collision if both boards are ever
  # plugged into the same host at once).
  boot.kernelModules = [ "g_ether" ];
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.6";
    prefixLength = 24;
  }];

  boot.loader = {
    generic-extlinux-compatible.enable = lib.mkForce false;
    grub.enable = lib.mkForce false;
  };

  hardware.bcm2835-rpi-zero-w = {
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
      repart.enable = true;
    };
  };

  matthew-hardware.image.repart.format = "btrfs";
}
