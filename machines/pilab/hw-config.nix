{ config, inputs, lib, ... }:
{
  imports = [
    inputs.raspberry-pi-nix.nixosModules.raspberry-pi
    inputs.raspberry-pi-nix.nixosModules.sd-image
  ];

  # Needed for building SD images.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  raspberry-pi-nix = {
    board = "bcm2712";
    # Both these kernels makes end0 ethernet network interface unable to get a DHCP lease.
    # kernel-version = "v6_12_17";
    # kernel-version = "v6_6_78";
  };
  hardware.raspberry-pi.config.all = {
    options = {
      usb_max_current_enable = {
        enable = true;
        value = 1;
      };
    };
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
    };
    dt-overlays = {
      disable-bt = {
        enable = true;
        params = { };
      };
      vc4-kms-v3d = {
        enable = false;
        params = { };
      };
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
    "10-homelab"."/media/HOMELAB_MEDIA" = {
      d = {
        group = "root";
        mode = "0755";
        user = "root";
      };
      h.argument = "+i";
    };
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
