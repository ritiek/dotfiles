# Hardware configuration for Radxa Cubie A7S (Allwinner A733 / sun60iw2)
{ pkgs, lib, ... }:
let
  cubieA7SKernel = pkgs.callPackage ./linux-cubie-a7s.nix { };
in
{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Vendor kernel + Radxa allwinner-bsp overlay - see linux-cubie-a7s.nix
  # for why a fully custom kernel is required (no mainline A733 support).
  boot.kernelPackages = pkgs.linuxPackagesFor cubieA7SKernel;

  hardware.enableRedistributableFirmware = true;

  # console=ttyAS0 (NOT ttyS0) is Allwinner's own serial driver naming.
  # earlycon address/UART0 mapping and console settings taken verbatim from
  # OctaneOS's working extlinux.conf (validated boot chain). DP-Alt-Mode
  # display args (cma=, video=) intentionally omitted - deferred along with
  # display bring-up to a later phase. NOTE: the base defconfig+fragment
  # DOES still compile in the BSP DRM/HDMI/eDP chain (confirmed by real
  # hardware boot) even though the DP-altmode workaround patches (1006-1010)
  # are deferred - these drivers just run unpatched/unused since no display
  # is attached.
  #
  # NOTE on console spam: the BSP sunxi-hdmi driver runs a kthread that
  # polls HPD state every ~20-50ms and logs an info-level "drm hdmi
  # detect: disconnect" line on every poll when no HDMI cable is attached
  # (headless setup). This floods the 115200-baud serial console, starving
  # the login getty on the same tty. Do NOT put a manual "loglevel=N" here -
  # nixos/modules/system/boot/kernel.nix unconditionally APPENDS its own
  # "loglevel=${toString config.boot.consoleLogLevel}" to the end of
  # boot.kernelParams, and the kernel takes the LAST duplicate cmdline
  # param - so any loglevel=N placed in this list gets silently overridden
  # by whatever `boot.consoleLogLevel` resolves to (nixos-generators'
  # sd-aarch64 format defaults this to `lib.mkDefault 7`, i.e. very
  # verbose). The actual fix is `boot.consoleLogLevel = 4;` in
  # configuration.nix, which also fixes the post-boot `kernel.printk`
  # sysctl kernel.nix sets from the same option.
  boot.kernelParams = [
    "earlycon=uart8250,mmio32,0x02500000"
    "keep_bootcon"
    "clk_ignore_unused"
    "console=ttyAS0,115200"
    "console=tty1"
    "usbcore.autosuspend=-1"
    # Prints "calling %pS @ %i" / "initcall %pS returned ..." at KERN_DEBUG
    # level for every driver init/probe call. Was added to trace a
    # suspected boot hang (see configuration.nix's boot.consoleLogLevel
    # comment for the full writeup) that turned out to just be a very
    # slow (~315s) PHY link autonegotiation, not an actual hang - so this
    # never ended up being the diagnostic that solved it (initcall_debug
    # only covers kernel-internal probe/init calls, not the userspace-
    # triggered "ip link up" event where the real delay was). Kept enabled
    # per explicit user preference. Needs boot.consoleLogLevel>=8 in
    # configuration.nix to actually see the KERN_DEBUG output.
    "initcall_debug"
    # HANG #6 (fixed at the DTS level, see sun60i-a733-cubie-a7s.dts'
    # reg_cldo2 node comment): after the PCK600 power-domain fix
    # resolved the dwc3/husb311 EPROBE_DEFER hang, boot progressed all
    # the way through systemd/Ethernet bring-up and then hung ~30s
    # later at "axp8191-cldo2: disabling" - the mainline regulator
    # core's late "disable unused regulators" cleanup
    # (regulator_late_cleanup() in drivers/regulator/core.c) trying to
    # turn off the cldo2 PMIC rail (an orphaned hdmi0 supply, since
    # CONFIG_AW_DRM=n means hdmi0 never claims it) via a hanging I2C
    # write. NOTE: `regulator_ignore_unused` was tried first here as a
    # kernel cmdline fix but did NOT work - this kernel's
    # drivers/regulator/core.c (radxa/kernel@allwinner-aiot-linux-6.6)
    # predates that upstream feature entirely (no such __setup handler
    # exists in this version), so the param was silently a no-op. The
    # real fix is marking cldo2 `regulator-boot-on`/`regulator-always-on`
    # in the DTS (matching sibling cldo1/cldo3), which makes the
    # cleanup pass skip it before ever attempting the disable.
  ];

  hardware.deviceTree = {
    enable = true;
    filter = "sun60i-a733-cubie-a7s.dtb";
  };

  # NixOS's default initrd module-closure computation pulls in a large
  # generic "installer" set of storage/RAID kernel modules (e.g. 3w-9xxx,
  # megaraid_sas, aacraid) so install media boots on arbitrary x86 hardware.
  # Our minimal headless A733 defconfig doesn't build these unused generic
  # modules, so `modprobe`'s dependency-closure check for them fails and
  # aborts the whole image build. None of this hardware exists on this
  # board, so disable pulling in the default module list entirely.
  boot.initrd.includeDefaultModules = false;
}
