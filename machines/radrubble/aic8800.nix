# AIC8800 WiFi driver for Radxa Zero 3W
# Based on https://github.com/radxa-pkg/aic8800
{ config, lib, pkgs, ... }:

let
  aic8800-src = pkgs.fetchFromGitHub {
    owner = "radxa-pkg";
    repo = "aic8800";
    rev = "c9176c164b3dd154d8fc7ae23c5f0cfd6b6553a3";
    hash = "sha256-ZamZ+nerZRFiHxaLx9x5vnRaATKvY7FkBsfkzsdL3wc=";
  };

  # Firmware - flat structure, uncompressed (driver uses filp_open, not request_firmware)
  aic8800-firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "aic8800-firmware";
    version = "2024.11.19";
    src = aic8800-src;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib/firmware/aic8800_fw/SDIO
      cp -r src/SDIO/driver_fw/fw/aic8800D80/* $out/lib/firmware/aic8800_fw/SDIO/
    '';
  };

  aic8800-driver = config.boot.kernelPackages.callPackage ({ stdenv, kernel }:
    stdenv.mkDerivation {
      pname = "aic8800-driver";
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
                 debian/patches/fix-sdio-firmware-path.patch \
                 debian/patches/fix-sdio-fall-through.patch; do
          [ -f "$p" ] && patch -p1 < "$p" || true
        done
        patch -p1 < ${./patches/aic8800-gpio-power.patch} || true
        runHook postPatch
      '';

      preBuild = "cd src/SDIO/driver_fw/driver/aic8800";

      buildPhase = ''
        runHook preBuild
        make KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
             ARCH=arm64 CROSS_COMPILE= modules
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
  boot.kernelModules = [ "aic8800_bsp" "aic8800_fdrv" ];

  # Point directly to nix store path - available immediately, no compression
  boot.extraModprobeConfig = ''
    options aic8800_bsp aic_fw_path=${aic8800-firmware}/lib/firmware/aic8800_fw/SDIO skip_power_wait=1
    options aic8800_fdrv aicwf_dbg_level=0
  '';
}
