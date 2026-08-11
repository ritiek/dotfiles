{ config, inputs, pkgs, lib, nixos-raspberrypi, ... }:

let
  homelabMediaPath = "/media/HOMELAB_MEDIA";
  everythingElsePath = "/media/EVERYTHING_ELSE";
  enableLEDs = true;
  isRpi5 = config.boot.loader.raspberry-pi.variant == "5";
in
{
  _module.args.homelabMediaPath = homelabMediaPath;
  _module.args.everythingElsePath = everythingElsePath;
  _module.args.enableLEDs = enableLEDs;

  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    sd-image
    usb-gadget-ethernet
    # Optional memory optimization: use 16k pages instead of default 64k for
    # jemalloc, saves memory, reduces fragmentation. May fix any issues caused
    # by the memory page size discrepancy. May cause lots of rebuilds.
    # (only for systems running default rpi5 (bcm2712) kernel with 16k memory page)
    # raspberry-pi-5.page-size-16k
  ];

  # Needed for building SD images.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # To see available kernel versions, run:
  # $ nix eval --impure --expr 'builtins.attrNames (builtins.getFlake "path:/etc/nixos").inputs.nixos-raspberrypi.legacyPackages.aarch64-linux.linuxAndFirmware
  # boot.kernelPackages = pkgs.linuxAndFirmware.v6_6_51.linuxPackages_rpi5;
  boot.kernelPackages = pkgs.linuxAndFirmware.latest.linuxPackages_rpi5;

  boot.kernelModules = [ "i2c-dev" "vhci-hcd" ];

  # Disable UAS for RTL9210B USB NVMe enclosures — UAS causes device reset
  # failures and drives going offline on Pi 5 (especially Micron NVMe).
  boot.kernelParams = [ "usb-storage.quirks=0bda:9210:u" ];

  boot.supportedFilesystems = [ "ntfs" ];
  
  # Increase font size in TTY console logs. This applies after NixOS enters stage 2 boot.
  console = {
    font = "ter-v32b";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };

  hardware.raspberry-pi.config.all = {
    options = {
      usb_max_current_enable = {
        enable = true;
        value = 1;
      };
      # console = {
      #   enable = true;
      #   value = "serial0,115200 console=tty1";
      # };
    };
    # EEPROM bootloader settings. NOT managed by Nix -- these live in the Pi 5's
    # on-board SPI flash (Winbond W25Q16.V, 2MB, /dev/spidev10.0). Read with
    # `vcgencmd bootloader_config`; edit with:
    #   nix-shell -p raspberrypi-eeprom flashrom \
    #     --run 'sudo env PATH="$PATH" rpi-eeprom-config --edit'
    # Current contents:
    #   [all]
    #   BOOT_UART=1
    #   BOOT_ORDER=0xf416          # read right-to-left: NVMe -> SD -> USB -> restart
    #   NET_INSTALL_AT_POWER_ON=1
    #
    # This machine boots with NO microSD card present. The second-stage
    # bootloader lives in the SPI flash above, and BOOT_ORDER=0xf416 makes it
    # load config.txt + kernel.img directly from nvme0n1p1 (see fileSystems
    # below). PCIE_PROBE=1 is NOT required: boot mode 6 alone is enough for the
    # bootloader to enumerate the Samsung 980 behind the ASM2806 PCIe switch.
    # Verified 2026-08-11 on bootloader release 2026-05-26. (Upstream support:
    # NVMe-behind-switch 2024-05-13, PCIe BAR fix 2024-10-21, >=32MB read fix
    # 2025-06-09 -- see raspberrypi/firmware#1833.)
    #
    # Check what it actually booted from:
    #   xxd -p /proc/device-tree/chosen/bootloader/boot-mode   # 06 = NVMe, 01 = SD
    #
    # Do NOT downgrade the bootloader below 2025-06-09: kernel.img is ~32.3 MiB
    # and older releases fail contiguous NVMe reads >= 32 MiB.
    #
    # A full backup of the SPI flash is at /root/pieeprom-backup-20260811-2248.bin
    # (restore: `flashrom -p linux_spi:dev=/dev/spidev10.0,spispeed=16000 -w <file>`).
    base-dt-params = {
      BOOT_UART = {
        value = 1;
        enable = true;
      };
      uart_2ndstage = {
        value = 1;
        enable = true;
      };
      # Force PCIe Gen 3 speeds.
      pciex1_gen = {
        value = 3;
        enable = true;
      };
      # Let BME680 work over I2C.
      # https://github.com/pimoroni/bme680-python
      i2c_arm = {
        value = "on";
        enable = true;
      };
      i2c_vc = {
        value = "on";
        enable = true;
      };
      spi = {
        value = "on";
        enable = true;
      };

      pwr_led_trigger = {
        value = "default-on";
        enable = !enableLEDs && isRpi5;
      };
      pwr_led_activelow = {
        value = "off";
        enable = !enableLEDs && isRpi5;
      };
      act_led_trigger = {
        value = "default-on";
        enable = !enableLEDs && isRpi5;
      };
      act_led_activelow = {
        value = "off";
        enable = !enableLEDs && isRpi5;
      };
      eth_led0 = {
        value = 4;
        enable = !enableLEDs && isRpi5;
      };
      eth_led1 = {
        value = 4;
        enable = !enableLEDs && isRpi5;
      };
    };

    dt-overlays = {
      # disable-bt = {
      #   enable = true;
      #   params = { };
      # };
      vc4-kms-v3d = {
        enable = false;
        params = { };
      };
      # uart0 = {
      #   enable = true;
      #   params = { };
      # };
    };
  };

  # Disk layout. Everything is on the Samsung 980 (nvme0n1) behind the ASM2806
  # PCIe switch on the Seeed dual-M.2 HAT. There is NO microSD card.
  #
  #   nvme0n1p1  1.1G  vfat  FIRMWARE          -> /boot/firmware
  #   nvme0n1p2  618G  ext4  NIXOS_SD          -> /
  #   nvme0n1p3  313G  ext4  NIX_BINARY_CACHE
  #   nvme1n1    1.8T  LUKS  HOMELAB_MEDIA     -> unlocked post-boot, see home/ritiek
  #
  # The label names are historical and misleading: NIXOS_SD and FIRMWARE are on
  # NVMe, not on an SD card. They are kept because the imported `sd-image`
  # module hardcodes them -- `/boot/firmware` resolves from
  # `by-label/${config.sdImage.firmwarePartitionName}` (= FIRMWARE) in nixpkgs
  # sd-image.nix, and `/` from NIXOS_SD here. Renaming them means overriding
  # both, so we relabel the disks instead of the config.
  #
  # The retired microSD is labelled FIRMWARE_SD / NIXOS_UNUSED_SD specifically
  # so that reinserting it does NOT collide with these labels. It still holds a
  # bootable clone of an old generation, but its cmdline.txt hardcodes an
  # init=/nix/store/... path that will eventually be garbage-collected.
  #
  # NOTE: do not create a FAT partition containing config.txt on nvme1n1. The
  # bootloader has no way to pin which NVMe device it boots from ("scan PCIe for
  # an NVMe device", singular), so a second bootable drive makes boot
  # non-deterministic. It is unambiguous today only because nvme1n1 is
  # whole-disk LUKS with no partition table.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      autoResize = true;
      options = [ "noatime" ];
    };
  };

  # Ref:
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#h
  systemd.tmpfiles.settings = {
    "10-homelab"."${homelabMediaPath}" = {
      d = {
        group = "root";
        mode = "0755";
        user = "root";
      };
      h.argument = "+i";
    };
    "10-everything-else"."${everythingElsePath}" = {
      d = {
        group = "root";
        mode = "0755";
        user = "root";
      };
      h.argument = "+i";
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [
      homelabMediaPath
    ];
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;

  # nixpkgs 26.11 removed `stdenv.hostPlatform.linux-kernel`, but the pinned
  # nixos-raspberrypi loader module still reads `linux-kernel.target` to set
  # `boot.loader.kernelFile` (modules/system/boot/loader/raspberrypi/default.nix).
  # Re-add it onto the host platform (`lib.systems.elaborate` preserves passed-in
  # attrs) so that broken definition evaluates to the correct value ("Image").
  # `mkForce` is required because nixos-raspberrypi's default config sets
  # `nixpkgs.hostPlatform = "aarch64-linux"` at normal priority. Drop this once
  # nixos-raspberrypi is bumped to a release that no longer references linux-kernel.
  nixpkgs.hostPlatform = lib.mkForce {
    system = "aarch64-linux";
    linux-kernel = { target = "Image"; };
  };
}
