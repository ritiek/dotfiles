# AIC8800D80 USB WiFi driver for Radxa Cubie A7S
# Based on https://github.com/radxa-pkg/aic8800 (USB variant)
#
# UNLIKE the in-tree BSP driver at radxa/allwinner-bsp (which only matches
# USB PID 0x8800/0x8801, NOT our chip's actual PID 0x8D80 - confirmed via
# research: neither aic8800_bsp/aicusb.c's aicwf_usb_id_table[] nor
# aic8800_fdrv/aicwf_usb.h's USB_PRODUCT_ID_AIC define ever match 0x8D80
# at our pinned BSP commit eaea60ad7c058ae347eeffacf715bc5d539850c2 - that
# PID/compat layer was only added in a later BSP restructuring commit),
# this uses the out-of-tree radxa-pkg/aic8800 "USB" driver tree, which
# ships the newer aic_load_fw module with 0x8D80-aware PID tables
# (aic_compat_8800d80.h). See RADXA_CUBIE_A7S_NIXOS_PLAN.md Phase 5
# section for the full investigation.
#
# Chip confirmed present via `cat /sys/kernel/debug/usb/devices` on the
# board: Vendor=a69c ProdID=8d80 Manufacturer=aicsemi Product="AIC Wlan"
# (AIC8800D80 variant), Driver=(none) before this module is loaded.
{ config, lib, pkgs, ... }:

let
  aic8800-src = pkgs.fetchFromGitHub {
    owner = "radxa-pkg";
    repo = "aic8800";
    # Same pin as RADXA_ZERO_3_NIXOS's SDIO aic8800.nix module - confirmed
    # this rev's tree also has the src/USB/driver_fw/drivers/aic8800/{aic_load_fw,aic8800_fdrv}
    # structure needed for the USB variant.
    rev = "c9176c164b3dd154d8fc7ae23c5f0cfd6b6553a3";
    hash = "sha256-ZamZ+nerZRFiHxaLx9x5vnRaATKvY7FkBsfkzsdL3wc=";
  };

  # Firmware - flat structure (driver uses filp_open/request_firmware with the
  # aic_fw_path module parameter as base directory, matching the upstream
  # fix-usb-firmware-path.patch's patched default of
  # "/lib/firmware/aic8800_fw/USB" for CONFIG_PLATFORM_UBUNTU builds).
  aic8800-firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "aic8800-usb-firmware";
    version = "2024.11.19";
    src = aic8800-src;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib/firmware/aic8800_fw/USB
      cp -r src/USB/driver_fw/fw/aic8800D80/* $out/lib/firmware/aic8800_fw/USB/
    '';
  };

  aic8800-driver = config.boot.kernelPackages.callPackage ({ stdenv, kernel }:
    stdenv.mkDerivation {
      pname = "aic8800-usb-driver";
      version = "2024.11.19-${kernel.version}";
      src = aic8800-src;
      nativeBuildInputs = kernel.moduleBuildDependencies;
      hardeningDisable = [ "pic" ];

      patchPhase = ''
        runHook prePatch
        for p in debian/patches/fix-linux-6.1-build.patch \
                 debian/patches/fix-linux-6.5-build.patch \
                 debian/patches/fix-linux-6.7-build.patch \
                 debian/patches/fix-linux-6.9-build.patch \
                 debian/patches/fix-linux-6.12-build.patch \
                 debian/patches/fix-usb-build.patch \
                 debian/patches/fix-usb-firmware-path.patch \
                 debian/patches/fix-usbc1-controller-wifi-rate-of-sun60iw2p1.patch; do
          [ -f "$p" ] && patch -p1 < "$p" || true
        done
        runHook postPatch
      '';

      # NOTE: plural "drivers" for the USB tree (unlike SDIO's singular "driver").
      preBuild = "cd src/USB/driver_fw/drivers/aic8800";

      # CONFIG_ARCH_SUN60IW2P1=y activates a Radxa-specific fix (via the
      # fix-usbc1-controller-wifi-rate-of-sun60iw2p1.patch applied above) inside
      # aic8800_fdrv/Makefile: CONFIG_USB_ALIGN_DATA=n + CONFIG_USB_NO_TRANS_DMA_MAP=y -
      # a sun60iw2p1 (Allwinner A733, our exact SoC) specific USB DMA/alignment
      # workaround that Radxa's own packaging already carries for this hardware.
      # NOTE: our custom kernel derivation (linux-cubie-a7s.nix) is a
      # single-output derivation, unlike nixpkgs' usual multi-output
      # buildLinux which has a dedicated `.dev` output - there is no
      # `kernel.dev`. Instead linux-cubie-a7s.nix's installPhase copies the
      # whole post-build source tree to $out/build for exactly this purpose.
      buildPhase = ''
        runHook preBuild
        make KDIR=${kernel}/build \
             ARCH=arm64 CROSS_COMPILE= CONFIG_ARCH_SUN60IW2P1=y modules
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800
        find . -name '*.ko' -exec cp {} $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800/ \;
        runHook postInstall
      '';
    }
  ) {};

in {
  boot.extraModulePackages = [ aic8800-driver ];
  # USB variant module names differ from SDIO: aic_load_fw (replaces aic8800_bsp) + aic8800_fdrv.
  boot.kernelModules = [ "aic_load_fw" "aic8800_fdrv" ];

  # Point directly to nix store path - available immediately, no /lib/firmware staging.
  boot.extraModprobeConfig = ''
    options aic_load_fw aic_fw_path=${aic8800-firmware}/lib/firmware/aic8800_fw/USB
    options aic8800_fdrv aicwf_dbg_level=0
  '';
}
