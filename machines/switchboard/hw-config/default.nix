{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  # Hardware support for the Radxa Cubie A5E (aic8800 wifi/bt driver, board
  # workarounds, disk/boot layout) is vendored locally in this directory
  # rather than pulled in as a flake input.
  # Source: https://github.com/patryk4815/nixos-cubie-a5e
  imports = [
    ./aic8800-sdio.nix
    ./cubie-a5e.nix
    ./disko.nix
  ];

  hardware.cubie-a5e.enable = true;

  # Pinned to match the nixos-cubie-a5e repo's own kernel version (the aic8800
  # SDIO wifi/bt driver requires kernel >= 7.0 - see ./aic8800-sdio.nix).
  boot.kernelPackages = pkgs.linuxPackages_7_0;

  # A523/A527 thermal sensor support (THS0/THS1) is provided via
  # boot.kernelPatches in ./cubie-a5e.nix (gated on hardware.cubie-a5e.enable
  # above), not here - do not duplicate that list in this file, since
  # boot.kernelPatches is list-typed and duplicate entries get concatenated,
  # causing patches to be applied twice (the second application then fails
  # with "Reversed (or previously applied) patch detected").

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelModules = [ "g_ether" ];

  # Serial console boot logging - mirrors alcove's setup (Cubie A7S,
  # ./../../alcove/hw-config.nix) but with this board's actual UART driver
  # name/address, confirmed live via `cat /proc/device-tree/chosen/stdout-path`
  # (serial0:115200n8) and `/proc/device-tree/aliases/serial0` (->
  # /soc/serial@2500000): A523/A527's UART0 is a standard 8250-compatible
  # (DesignWare) UART at 0x02500000, so unlike alcove's A733 (non-standard
  # "ttyAS0" sunxi-uart driver naming), this board uses the generic "ttyS0".
  #
  # nixpkgs' sd-image-aarch64.nix (imported via ./disko.nix) already sets a
  # mkDefault console=ttyS0,115200n8 console=ttyAMA0,115200n8 console=tty0,
  # which is why boot logging over UART already works today - but that's
  # implicit/inherited rather than something this config documents or pins,
  # and it has no earlycon (so very-early boot messages, before the real
  # 8250 driver probes, are lost). Set it explicitly here so it survives
  # regardless of which medium the image is written to (SD, where the BROM
  # reads the embedded U-Boot, vs USB/NVMe, where it comes from SPI NOR),
  # and so the mainline U-Boot boot chain has full console visibility for
  # debugging.
  boot.kernelParams = [
    "earlycon=uart8250,mmio32,0x02500000"
    "keep_bootcon"
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  # See alcove/cubie-a7s.nix's comment for the full writeup on why this
  # needs to be set explicitly rather than left at nixpkgs' mkDefault:
  # nixos/modules/system/boot/kernel.nix unconditionally appends
  # "loglevel=${toString config.boot.consoleLogLevel}" to the end of
  # boot.kernelParams, and the kernel takes the LAST duplicate cmdline
  # param - so this is the only way to actually control verbosity.
  boot.consoleLogLevel = 8;

  # Guarantee a login shell over UART even if console= auto-detection ever
  # changes (systemd-getty-generator already starts this automatically
  # today since ttyS0 is a recognized console= name, but make it explicit
  # like alcove does for a hard guarantee).
  systemd.services."serial-getty@ttyS0".wantedBy = [ "getty.target" ];

  # USB gadget ethernet - allows SSH over USB-C on first boot
  # Connect to 10.0.0.4 from host (configure host side as 10.0.0.1/24)
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.4";
    prefixLength = 24;
  }];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
