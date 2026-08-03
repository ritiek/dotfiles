# Hardware/boot-chain wiring for zerokvm (Raspberry Pi Zero 2 W running as a
# PiKVM appliance). Ported from /home/ritiek/nixkvm's flake.nix (matthewcroughan's
# nixkvm fork with real kvmd daemon support), simplified to a single board
# (rpiVersion = 3, Pi Zero 2 W only) and restructured to directly import
# sd-image-aarch64.nix the same way machines/alcove/hw-config.nix does, so we
# get access to sdImage.populateFirmwareCommands.
{ config, lib, pkgs, modulesPath, inputs, ... }:

let
  # The kernel expression below is modelled on /home/ritiek/nixkvm's
  # mkPiKvmKernel: nixos-hardware's RPi kernel plus PiKVM's four out-of-tree
  # patches (HID remote wakeup, HID set_report_buf cleanup, mass-storage DVD
  # support, mass-storage INQUIRY fixes), which are what make USB HID emulation
  # and virtual media work on this board.
  #
  # Every input here feeds the kernel derivation hash: the nixpkgs revision
  # (a kernel embeds its whole build toolchain — gcc, binutils, bash, perl),
  # the nixos-hardware revision, the kvmd-nix revision that supplies the
  # patches, the patch `name` strings, and any structuredExtraConfig override.
  # So any bump to the flake inputs means a full kernel recompile. That must be
  # built somewhere real and pushed to the attic BEFORE deploying — the Pi Zero
  # 2 W (4 cores, ~400MiB RAM) cannot build this itself.
  #
  # This used to be pinned to a set of zerokvm-specific flake inputs
  # (nixpkgs-pikvm / nixos-hardware-pikvm / a fixed kvmd-nix rev, copied from
  # nixkvm's flake.lock) purely so the kernel kept hashing to the already-cached
  # linux-rpi-6.18.34-stable_20260609. Those pins have been retired in favour of
  # the shared inputs; the cost is that input bumps now cost a kernel build.

  patchDir = "${inputs.kvmd-nix.packages.${pkgs.stdenv.hostPlatform.system}.pikvm-packages}/packages/linux-rpi-pikvm";
  pikvmKernelPatches = [
    { name = "pikvm-hid-remote-wakeup"; patch = "${patchDir}/1001-pikvm-hid-remote-wakeup-support.patch"; }
    { name = "pikvm-hid-clean-set-report-buf"; patch = "${patchDir}/1002-pikvm-hid-clean-set_report_buf-on-hidg-disabling.patch"; }
    { name = "pikvm-msd-dvd-support"; patch = "${patchDir}/2001-pikvm-msd-dvd-support.patch"; }
    { name = "pikvm-msd-inquiry-flash-cdrom"; patch = "${patchDir}/2002-pikvm-msd-inquiry-for-flash-and-cdrom.patch"; }
  ];

  # Previous approach, kept for reference: the same four patches vendored
  # locally into ./patches (upstream provenance: pikvm/packages @
  # 5e87241398d3ca9bd01d20a740218229ac4f485d, packages/linux-rpi-pikvm/),
  # matching the machines/alcove and machines/radrubble convention of
  # vendoring board-specific kernel patches instead of pulling them from a
  # flake input's package output at eval time. Abandoned so the patches track
  # kvmd-nix rather than needing a manual refresh, and to keep the patch set
  # and the kvmd daemon that depends on it moving in lockstep.
  # pikvmKernelPatches = [
  #   { name = "pikvm-hid-remote-wakeup"; patch = ./patches/1001-pikvm-hid-remote-wakeup-support.patch; }
  #   { name = "pikvm-hid-clean-set-report-buf"; patch = ./patches/1002-pikvm-hid-clean-set_report_buf-on-hidg-disabling.patch; }
  #   { name = "pikvm-msd-dvd-support"; patch = ./patches/2001-pikvm-msd-dvd-support.patch; }
  #   { name = "pikvm-msd-inquiry-flash-cdrom"; patch = ./patches/2002-pikvm-msd-inquiry-for-flash-and-cdrom.patch; }
  # ];
  #
  # DEAD WEIGHT: the four .patch files under ./patches are therefore no longer
  # referenced by anything — nothing in this repo reads them. They are kept
  # only so the block above can be re-enabled without re-fetching them, and as
  # a record of the exact patches this appliance's kernel carries. Safe to
  # delete along with the commented-out list whenever this is cleaned up.

  # nixos-hardware's raspberry-pi/common/kernel.nix ignores plain
  # boot.kernelPatches; patches must go through argsOverride
  # (nixos-hardware#1745), matching kvmd-nix's own modules/variants/rpi4.nix.
  baseKernel = pkgs.callPackage "${inputs.nixos-hardware}/raspberry-pi/common/kernel.nix" {
    rpiVersion = 3;
  };

  # nixos-hardware's kernel.nix forces PREEMPT=yes / PREEMPT_LAZY=no /
  # PREEMPT_VOLUNTARY=no for rpiVersion>=3 (see kernel.nix's own comment citing
  # nixos-hardware#1920 and nixpkgs#531605), but never addresses the 4th member
  # of the kernel's exclusive "Preemption Model" Kconfig choice group,
  # PREEMPT_NONE. On this nixos-hardware rev the kernel's own config-generation
  # script (generate-config.pl) dies with "conflicting answers!" on that choice
  # group even with nixos-hardware's fix applied, so all 4 members are forced
  # explicitly to saturate the choice and close the ambiguity. baseKernel's
  # structuredExtraConfig is reused as the base so its other legitimate
  # overrides (NR_CPUS, CMA_SIZE_MBYTES, NFS_FS, ...) survive.
  zerokvmKernelPackages = pkgs.linuxPackagesFor (baseKernel.override {
    argsOverride = {
      kernelPatches = baseKernel.kernelPatches ++ pikvmKernelPatches;
      structuredExtraConfig = baseKernel.structuredExtraConfig // {
        PREEMPT = lib.mkForce (pkgs.lib.kernel.yes);
        PREEMPT_LAZY = lib.mkForce (pkgs.lib.kernel.no);
        PREEMPT_VOLUNTARY = lib.mkForce (pkgs.lib.kernel.no);
        PREEMPT_NONE = lib.mkForce (pkgs.lib.kernel.no);
      };
    };
  });

  boardDtbRelPath = "broadcom/bcm2837-rpi-zero-2-w.dtb";

  # NixOS's U-Boot + generic boot chain loads DTBs straight from a static
  # FDTDIR, bypassing RPi firmware's config.txt `dtoverlay=` mechanism, and
  # RPi's own overlays (incl. tc358743.dtbo) all declare
  # `compatible = "brcm,bcm2835"`, so nixpkgs' hardware.deviceTree.overlays
  # silently no-ops on modern boards. Instead we call `fdtoverlay` (from
  # pkgs.dtc) directly to merge tc358743.dtbo (HDMI-to-CSI capture) + a
  # hand-written dwc2-peripheral overlay (USB OTG gadget mode) into the one
  # target board DTB.
  dwc2PeripheralDts = pkgs.writeText "dwc2-peripheral.dts" ''
    /dts-v1/;
    /plugin/;
    / {
      compatible = "brcm,bcm2835";
      fragment@0 {
        target = <&usb>;
        __overlay__ {
          compatible = "brcm,bcm2835-usb";
          dr_mode = "peripheral";
          g-np-tx-fifo-size = <32>;
          g-rx-fifo-size = <558>;
          g-tx-fifo-size = <512 512 512 512 512 256 256>;
          status = "okay";
        };
      };
    };
  '';
  mergedDeviceTree = pkgs.runCommand "zerokvm-device-tree-merged" {
    nativeBuildInputs = [ pkgs.dtc ];
  } ''
    cp -r ${zerokvmKernelPackages.kernel}/dtbs $out
    chmod -R u+w $out
    dtc -@ -I dts -O dtb -o dwc2-peripheral.dtbo ${dwc2PeripheralDts}
    fdtoverlay -i "$out/${boardDtbRelPath}" -o merged.dtb \
      ${pkgs.raspberrypifw}/share/raspberrypi/boot/overlays/tc358743.dtbo \
      dwc2-peripheral.dtbo
    mv merged.dtb "$out/${boardDtbRelPath}"
  '';
in
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  boot.kernelPackages = zerokvmKernelPackages;
  hardware.deviceTree.package = lib.mkForce mergedDeviceTree;

  services.kvmd = {
    enable = true;
    variant = "v2-hdmi-zero2w";
    janus.enable = true;
    janus.openFirewall = true;
  };

  boot.kernelModules = [ "dwc2" "tc358743" ];
  boot.kernelParams = [ "cma=192M" ];
  # sd-image-aarch64's cross-SBC initrd list FATALs on modules the rpi
  # kernel lacks; force the minimal set it actually has.
  boot.initrd.availableKernelModules = lib.mkForce [ "ext4" "mmc_block" "usbhid" "usb_storage" "xhci_hcd" "vc4" "pcie-brcmstb" "reset-raspberrypi" ];
  services.udev.extraRules = ''
    KERNEL=="vcio", GROUP="video", MODE="0660"
  '';

  # Append our overlays to the config.txt already written by
  # sd-image-aarch64.nix (populateFirmwareCommands has no declared type, so
  # plain string concatenation applies; mkAfter guarantees our lines land
  # after the base module's script runs).
  sdImage.populateFirmwareCommands = lib.mkAfter ''
    # sd-image-aarch64.nix copies config.txt from the Nix store, which
    # lands read-only; make it writable before appending.
    chmod +w firmware/config.txt
    cat >> firmware/config.txt << 'CONFIGTXT'

    [all]
    dtoverlay=dwc2,dr_mode=peripheral
    dtoverlay=tc358743
    CONFIGTXT

    # sd-image-aarch64.nix doesn't copy overlays/ from raspberrypifw, but
    # dtoverlay=tc358743 and dtoverlay=dwc2 need the .dtbo files.
    cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/overlays firmware/
  '';

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
