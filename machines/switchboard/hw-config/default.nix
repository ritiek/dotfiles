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

  # One ComboPHY, shared: PCIe/NVMe or USB 3.0, never both. Keep it on PCIe.
  #
  # "usb3" was tried (fd9c88c) and reverted: it does flip the PHY (verified
  # live, /proc/device-tree/soc/phy@4f00000 status=okay phy_use_sel=1) but
  # nothing drives it. Our patch set has the INNO combo PHY driver
  # (patches/drv-phy-allwinner-add-pcie-usb3-driver.patch) yet the dtsi patch
  # adds no xHCI/DWC3 controller node - only the vendor-style usbc1@11, which
  # mainline's xhci-platform cannot bind. So the USB ports stayed at 480 Mbps
  # and PCIe was lost for nothing. PCIe works because
  # patches/drv-pci-sunxi-enable-pcie-support.patch supplies a real controller
  # driver; there is no USB3 equivalent. Revisit only if an xHCI node lands.
  hardware.cubie-a5e.combophy = "pcie";

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

  # Serial console boot logging. Only earlycon is added here, deliberately.
  #
  # This board's UART0 is a standard 8250-compatible (DesignWare) controller at
  # 0x02500000, confirmed live via `cat /proc/device-tree/chosen/stdout-path`
  # (serial0:115200n8) and `/proc/device-tree/aliases/serial0` (->
  # /soc/serial@2500000). That differs from alcove's A733, which needs the
  # non-standard "ttyAS0" sunxi-uart naming (see ../../alcove/cubie-a7s.nix).
  #
  # Do NOT re-declare console= entries here. nixpkgs' sd-image-aarch64.nix
  # (imported via ./disko.nix) already sets console=ttyS0,115200n8
  # console=ttyAMA0,115200n8 console=tty0 at NORMAL priority
  # (nixos/modules/installer/sd-card/sd-image-aarch64.nix:24-28 - not
  # mkDefault), and boot.kernelParams is list-typed, so repeats are
  # concatenated rather than deduplicated. What the module does not provide is
  # earlycon, so very early messages - before the real 8250 driver probes -
  # were being lost. That is the only gap filled here.
  #
  # Do NOT add "keep_bootcon" either. It was tried, and it makes the kernel
  # print every message twice over UART: earlycon and the real ttyS0 driver
  # are two separate consoles pointing at the SAME controller, and the kernel
  # would normally unregister the boot console at handover. keep_bootcon
  # suppresses exactly that, leaving both registered - confirmed live in
  # /proc/consoles, which listed "ttyS0 ... (E   p a)" alongside
  # "uart8250 ... (E B p  )" (B = boot console) with both enabled. At 115200
  # baud with loglevel=8 the duplication measurably slows boot. It buys
  # nothing here: earlycon still covers the pre-probe window and hands over
  # cleanly, and ttyS0 registers reliably on this board.
  boot.kernelParams = [
    "earlycon=uart8250,mmio32,0x02500000"
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
