# AIC8800 WiFi + Bluetooth for Radxa Zero 3W, set up the way Armbian does it
# (radxa-pkg/aic8800 sdio DKMS + aic-bluetooth hciattach service).
{ config, lib, pkgs, ... }:

let
  aic8800-src = pkgs.fetchFromGitHub {
    owner = "radxa-pkg";
    repo = "aic8800";
    rev = "d13d07963cd15d731e2895e8288a04cca6152ac9"; # 5.0+git20260123.5f7be68d-9
    hash = "sha256-7p3aa4gR622icOaSQKNtgp974f2ijGxa/l3I2+8RIYo=";
  };

  # Firmware - flat structure, uncompressed (driver uses filp_open, not request_firmware)
  aic8800-firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "aic8800-firmware";
    version = "5.0-unstable-2026-01-23";
    src = aic8800-src;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib/firmware/aic8800_fw/SDIO
      cp -r src/SDIO/driver_fw/fw/aic8800D80/* $out/lib/firmware/aic8800_fw/SDIO/
    '';
  };

  aic8800-driver = config.boot.kernelPackages.callPackage ({ stdenv, kernel, patchutils }:
    stdenv.mkDerivation {
      pname = "aic8800-driver";
      version = "5.0-unstable-2026-01-23-${kernel.version}";
      src = aic8800-src;
      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ patchutils ];
      hardeningDisable = [ "pic" ];

      # Debian's full series, SDIO parts only (some USB/PCIE hunks are CRLF and
      # don't apply with plain patch).
      patchPhase = ''
        runHook prePatch
        for p in $(grep -v '^#' debian/patches/series); do
          filterdiff -p1 -i 'src/SDIO/*' "debian/patches/$p" | patch -p1 --no-backup-if-mismatch
        done
        patch -p1 < ${./patches/aic8800-gpio-power.patch}
        # 6.12.108 backported the 6.13 set_monitor_channel signature
        patch -p1 < ${./patches/aic8800-linux-6.12.108-set-monitor-channel.patch}
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
  boot.kernelModules = [ "aic8800_bsp" "aic8800_fdrv" "aic8800_btlpm" ];

  # Point directly to nix store path - available immediately, no compression
  boot.extraModprobeConfig = ''
    options aic8800_bsp aic_fw_path=${aic8800-firmware}/lib/firmware/aic8800_fw/SDIO skip_power_wait=1
    options aic8800_fdrv aicwf_dbg_level=0 custregd=0 ps_on=0
  '';

  hardware.bluetooth.enable = true;

  # Port of Armbian's packages/bsp/aic8800/aic-bluetooth: BT is on uart1 (ttyS1).
  systemd.services.aic-bluetooth = {
    description = "AIC8800 Bluetooth (hciattach on ttyS1)";
    after = [ "bluetooth.service" ];
    requires = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ bluez util-linux procps coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      rfkill unblock all
      hciattach -r -s 1500000 /dev/ttyS1 any 1500000 flow nosleep
      sleep .5
      pkill -f /dev/ttyS1 || true
      sleep .5
      hciattach -s 1500000 /dev/ttyS1 any 1500000 flow nosleep
      rfkill unblock all
    '';
  };
}
