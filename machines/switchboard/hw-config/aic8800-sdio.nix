
# Vendored from https://github.com/patryk4815/nixos-cubie-a5e
# (modules/aic8800-sdio.nix)
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hardware.aic8800;

  aic8800-sdio-driver = config.boot.kernelPackages.callPackage (
    { stdenv, fetchFromGitHub, kernel, kmod }:
    stdenv.mkDerivation {
      pname = "aic8800-sdio";
      version = "5.0-unstable-2026-01-23";

      src = fetchFromGitHub {
        owner = "radxa-pkg";
        repo = "aic8800";
        rev = "7f42b22913b462ab6c658dfc075bae1dbfe9a71a";
        hash = "sha256-WaFE8nwFHn4ws+kLhhWZgrFOQHfJ5ByaEjpfjpv131s=";
      };

      sourceRoot = "source/src/SDIO/driver_fw/driver/aic8800";

      patchFlags = [ "-p6" ];
      patches = [ ./aic8800-kernel-7.0.patch ];

      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ kmod ];

      makeFlags = [
        "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "ARCH=${stdenv.hostPlatform.linuxArch}"
        "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
        "CONFIG_PLATFORM_UBUNTU=y"
        "CONFIG_PLATFORM_ALLWINNER=n"
      ];

      installPhase = ''
        runHook preInstall
        install -Dm644 aic8800_bsp/aic8800_bsp.ko $out/lib/modules/${kernel.modDirVersion}/extra/aic8800_bsp_sdio.ko
        install -Dm644 aic8800_fdrv/aic8800_fdrv.ko $out/lib/modules/${kernel.modDirVersion}/extra/aic8800_fdrv_sdio.ko
        install -Dm644 aic8800_btlpm/aic8800_btlpm.ko $out/lib/modules/${kernel.modDirVersion}/extra/aic8800_btlpm_sdio.ko
        runHook postInstall
      '';

      meta = with lib; {
        description = "AIC8800 SDIO WiFi/Bluetooth driver";
        homepage = "https://github.com/radxa-pkg/aic8800";
        license = licenses.gpl2Only;
        platforms = platforms.linux;
      };
    }
  ) {};

  aic8800-firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "aic8800-firmware";
    version = "5.0-unstable-2026-01-23";

    src = pkgs.fetchFromGitHub {
      owner = "radxa-pkg";
      repo = "aic8800";
      rev = "7f42b22913b462ab6c658dfc075bae1dbfe9a71a";
      hash = "sha256-WaFE8nwFHn4ws+kLhhWZgrFOQHfJ5ByaEjpfjpv131s=";
    };

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/firmware/aic8800
      cp -r src/SDIO/driver_fw/fw/* $out/lib/firmware/aic8800/
      runHook postInstall
    '';

    compressFirmware = false;

    meta = with lib; {
      description = "AIC8800 WiFi/Bluetooth firmware";
      homepage = "https://github.com/radxa-pkg/aic8800";
      license = licenses.unfreeRedistributableFirmware;
      platforms = platforms.linux;
    };
  };
in
{
  options.hardware.aic8800 = {
    enable = lib.mkEnableOption "AIC8800 SDIO WiFi/Bluetooth support";
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.0";
      message = "hardware.aic8800 requires kernel >= 7.0 (patch is for kernel 7.0 API changes)";
    }];

    boot.extraModulePackages = [ aic8800-sdio-driver ];

    boot.kernelModules = [
      "aic8800_bsp_sdio"
      "aic8800_fdrv_sdio"
      "aic8800_btlpm_sdio"
    ];

    hardware.firmware = [ aic8800-firmware ];

    # AIC8800 firmware path, plus log level.
    #
    # The vendor driver ships with tracing on: aic8800_fdrv defaults
    # aicwf_dbg_level to LOGERROR|LOGINFO|LOGTRACE|LOGDEBUG|LOGFW (0x40f =
    # 1039), which floods the console with per-command and per-packet noise
    # like "AICWFDBG(LOGTRACE) rwnx_cmd_malloc" and "AICWFDBG(LOGDEBUG)
    # rwnx_rx_handle_msg msg->id:0x62" - continuously, in normal operation,
    # not just during bring-up. On a board whose console is a 115200 baud
    # UART that is genuinely expensive, and it buries anything useful.
    #
    # Bits, from aic8800_fdrv/aicwf_debug.h at the pinned rev:
    #   LOGERROR 0x001  LOGINFO   0x002  LOGTRACE   0x004  LOGDEBUG 0x008
    #   LOGDATA  0x010  LOGSTEER  0x020  LOGSDPWRC  0x040  LOGWAKELOCK 0x080
    #   LOGRXPOLL 0x100 LOGIRQ    0x200  LOGFW      0x400
    #
    # 3 = LOGERROR|LOGINFO keeps real failures and association/state
    # messages while dropping the per-command and per-packet chatter. The
    # param is writable at runtime (mode 0660), so debugging does not need a
    # rebuild:
    #   echo 1039 | sudo tee /sys/module/aic8800_fdrv/parameters/aicwf_dbg_level
    #
    # Note the modprobe name is the .ko name (aic8800_fdrv_sdio) while
    # /sys/module uses the module's internal name (aic8800_fdrv) - same
    # asymmetry as aic8800_bsp_sdio vs aic8800_bsp below.
    #
    # aic8800_bsp has its own aicwf_dbg_level_bsp declared in
    # aic_bsp_driver.h, but it is not a module_param in this build (only
    # adap_test, aic_fw_path and testmode are exposed), so bsp-level
    # messages cannot be tuned without patching the driver.
    boot.extraModprobeConfig = ''
      options aic8800_bsp_sdio aic_fw_path=/run/booted-system/firmware/aic8800/aic8800D80
      options aic8800_fdrv_sdio aicwf_dbg_level=3
    '';

    # Bluetooth HCI over UART1
    hardware.bluetooth.enable = true;
    systemd.services.aic8800-bluetooth = {
      description = "AIC8800 Bluetooth HCI attach";
      after = [ "dev-ttyS1.device" ];
      requires = [ "dev-ttyS1.device" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "bluetooth.service" ];
      serviceConfig = {
        Type = "forking";
        ExecStart = "${pkgs.bluez}/bin/hciattach /dev/ttyS1 any 1500000 flow";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };

    # DTB overlay - enable mmc1 (SDIO1) for WiFi
    hardware.deviceTree = {
      enable = true;
      overlays = [{
        name = "cubie-a5e-wifi";
        dtsFile = ./wifi-overlay.dts;
      }];
    };
  };
}
