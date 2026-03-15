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

  boot.kernelModules = [ "i2c-dev" ];

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
    # Settings currently on my Pi5.
    # [all]
    # BOOT_UART=1
    # BOOT_ORDER=0xf461
    # NET_INSTALL_AT_POWER_ON=1
    # POWER_OFF_ON_HALT=1
    # WAKE_ON_GPIO=0
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

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
