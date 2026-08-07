
# Vendored from https://github.com/patryk4815/nixos-cubie-a5e
# (modules/cubie-a5e.nix)
{ pkgs, lib, config, ... }:
let
  cfg = config.hardware.cubie-a5e;
in
{
  options.hardware.cubie-a5e = {
    enable = lib.mkEnableOption "Radxa Cubie A5E board support";

    combophy = lib.mkOption {
      type = lib.types.enum [ "pcie" "usb3" ];
      default = "pcie";
      description = "Combo PHY mode: \"pcie\" for NVMe/M.2 (default), \"usb3\" for USB 3.0 SuperSpeed";
    };

    spi-nor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPI0 and expose the SPI NOR chip as /dev/mtd0 (for reflashing U-Boot from Linux)";
    };

    watchdog-reboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable watchdog-based reboot workaround for WIP TF-A (no PSCI SYSTEM_RESET)";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.aic8800.enable = true;

    boot.kernelPatches = [
      # Thermal sensor support (THS0/THS1) - backported from upstream
      # https://patchew.org/linux/20260704171411.1413349-1-iuncuim@gmail.com/
      { name = "sun55i-a523-thermal-1-dt-bindings"; patch = ./patches/0001-dt-bindings-thermal-sun8i-add-a523-ths.patch; }
      { name = "sun55i-a523-thermal-2-reset-control-shared"; patch = ./patches/0002-thermal-sun8i-reset-control-shared-deasserted.patch; }
      { name = "sun55i-a523-thermal-3-two-nvmem-cells"; patch = ./patches/0003-thermal-sun8i-calibration-two-nvmem-cells.patch; }
      { name = "sun55i-a523-thermal-4-ths0-ths1-driver"; patch = ./patches/0004-thermal-sun8i-add-a523-ths0-ths1-support.patch; }
      { name = "sun55i-a523-thermal-5-dts-sensors-zones"; patch = ./patches/0005-arm64-dts-allwinner-sun55i-add-thermal-sensors.patch; }
      # PCIe + combo PHY support - from Armbian (Marvin Wewer)
      { name = "a523-clk-usb3-ref"; patch = ./patches/drv-clk-sunxi-ng-fix-clock-handling-for-ccu-sun55i-a523.patch; }
      { name = "a523-combophy"; patch = ./patches/drv-phy-allwinner-add-pcie-usb3-driver.patch; }
      { name = "a523-pcie-rc"; patch = ./patches/drv-pci-sunxi-enable-pcie-support.patch; }
      { name = "a523-pcie-dts"; patch = ./patches/arm64-dts-sun55i-dtsi-add-iommu-usbc-pcie-combophy-nodes.patch; }
      { name = "a523-cubie-pcie-dts"; patch = ./patches/arm64-dts-sun55i-a527-cubie-a5e-enable-usbc-pcie-combophy.patch; }
      {
        name = "a523-pcie-config";
        patch = null;
        structuredExtraConfig = {
          PCIE_SUN55I_RC = lib.kernel.yes;
          AW_INNO_COMBOPHY = lib.kernel.yes;
          PCI_MSI = lib.kernel.yes;
        };
      }
    ];

    hardware.deviceTree.overlays =
      # Combo PHY: switch to USB 3.0 mode (default is PCIe/NVMe from kernel patch)
      lib.optionals (cfg.combophy == "usb3") [{
        name = "cubie-a5e-usb3";
        dtsFile = ./usb3-overlay.dts;
      }]
      # Expose the SPI NOR chip as /dev/mtd0 so it can be reflashed from Linux
      ++ lib.optionals cfg.spi-nor [{
        name = "cubie-a5e-spi-nor";
        dtsFile = ./spi-nor-overlay.dts;
      }];

    # Hardware watchdog for reliable reboot/shutdown detection
    systemd.settings.Manager = {
      RuntimeWatchdogSec = "15s";
      RebootWatchdogSec = "15s";
    };

    # Workaround: WIP TF-A doesn't support PSCI SYSTEM_RESET
    # Crash kernel on shutdown so hardware watchdog triggers reboot
    systemd.services.watchdog-reboot-helper = lib.mkIf cfg.watchdog-reboot {
      description = "Crash kernel for reboot";
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown.target" ];
      conflicts = [ "shutdown.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        ExecStop = "${pkgs.bash}/bin/bash -c 'echo c > /proc/sysrq-trigger'";
      };
    };
  };
}
