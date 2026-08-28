
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
      # CPU DVFS. Mainline models no CPU clock at all: the A523/A527 CPU PLLs
      # live in an undocumented "CPC" block at 0x08817000, outside the CCU at
      # 0x02001000 that ccu-sun55i-a523.c drives. With no clock and no OPP
      # table, cpufreq-dt never probes, so the cores stay wherever the boot
      # firmware parked them -- measured at 1032 MHz on this board, against a
      # rated 1.8 GHz big / 1.4 GHz little. It also means the 70/90 degC
      # passive trips added by the thermal patches above have no cooling
      # device bound to them and do nothing.
      #
      # These two patches are iuncuim's out-of-tree series (same author as the
      # THS thermal patches above), rebased onto 7.0.13 with two deliberate
      # local deviations documented in a523-cpu-opp-dts.patch:
      #   - the 1992 MHz OPP is dropped; it needs 1.22 V, above the 1.16 V
      #     ceiling declared for reg_dcdc1_323, and is only valid on speed
      #     bin vf0400 anyway
      #   - capacity-dmips-mhz is 922 (little) / 1024 (big) per the vendor
      #     BSP, not upstream's uniform 1024, so the scheduler can tell the
      #     asymmetric clusters apart
      #
      # No Kconfig additions needed: CPU_FREQ, CPUFREQ_DT, CPUFREQ_DT_PLATDEV,
      # PM_OPP, CPU_FREQ_THERMAL and SUN55I_A523_CCU are all already enabled,
      # and allwinner,sun55i-* is absent from cpufreq-dt-platdev's blocklist,
      # so the platform device is created off cpu0's operating-points-v2.
      { name = "a523-cpu-ccu-driver"; patch = ./patches/a523-cpu-ccu-driver.patch; }
      { name = "a523-cpu-opp-dts"; patch = ./patches/a523-cpu-opp-dts.patch; }

      # The CCU driver above reprograms the CPU PLL in place while the cluster
      # is still executing from it. That survives a small change of the N
      # multiplier but hangs the machine outright on a large one: U-Boot leaves
      # both clusters at 768 MHz (N=32), cpufreq snaps them to the nearest
      # listed OPP (792 MHz / N=33 and 840 MHz / N=35, both fine), and then the
      # governor asks for the maximum (1416 MHz / N=59 and 1800 MHz / N=75) and
      # the board dies with no further console output. Park the cluster on the
      # 24 MHz oscillator for the duration of the relock, exactly as every
      # other sunxi-ng CPU clock driver does.
      #
      # NOTE: a per-OPP bisect on the other card showed the relock is NOT what
      # hangs the board (the fatal step is only a 6-step change of N, smaller
      # than several steps that survived), so this is a correctness fix rather
      # than the cure. Kept in sync with the minimal config and the OpenWrt tree.
      { name = "a523-cpu-mux-bypass"; patch = ./patches/a523-cpu-mux-bypass.patch; }

      # The AXP323's DCDC1 and DCDC2 are ganged on this board as a two-phase
      # supply for vdd-cpub (the four "big" cores) -- mainline's own board DTS
      # says so. The kernel only ever *reads* the poly-phase bit and never sets
      # it, so whether the phases are actually ganged is inherited from the
      # bootloader. With it clear, DCDC1 alone feeds the cluster: voltage
      # scaling still works, but the rail browns out once the cluster draws
      # more current than one phase can deliver and the SoC dies silently.
      # Bisected on the minimal-config card: 408/672/840/1008 MHz (900 mV) and
      # 1200 MHz (920 mV) stable, 1344 MHz (960 mV) instant hang.
      #
      # This machine reaches 1800 MHz today only because its bootloader leaves
      # the bit set. Force it so the result stops depending on that.
      { name = "a523-axp323-force-polyphase"; patch = ./patches/a523-axp323-force-polyphase.patch; }
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
