# Minimal headless-only Linux 6.6 kernel for the Radxa Cubie A7S
# (Allwinner A733 / sun60iw2).
#
# There is no mainline Linux support for the A733 yet (blocked upstream on
# A733 clock-driver support landing first). Every working project for this
# board (Batocera/OctaneOS, NickAlilovic's Armbian fork) instead merges
# Radxa's own vendor kernel fork with Radxa's separate "allwinner-bsp"
# overlay repo, which supplies replacement drivers (MMC, Ethernet, PMIC,
# clocks/CCU, interrupt controller wakeup logic) that the vanilla Radxa
# kernel tree cannot function without. This merge is NOT a simple source
# fetch - it requires copying the BSP tree into a bsp/ subdirectory, fixing
# up Buildroot-incompatible Kconfig path variables, symlinking a driver
# directory so its #include paths resolve, and copying in SoC/board
# devicetree files that don't exist anywhere else. All of this mirrors
# GameOctane/OctaneOS's `scripts/setup-kernel-66.sh` (steps 3-8), which we
# replicate below.
#
# Scope (user-selected "minimal headless-only first" option, 2026-07-02):
# only the patches needed for cpufreq + basic USB-PD/TypeC negotiation are
# applied. DisplayPort-Alt-Mode workarounds and the xpad joystick fix
# (OctaneOS patches 1006-1012) are deliberately deferred to a later
# display/gamepad bring-up phase - this build targets boot + serial console
# + Ethernet + SSH only.
{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, bc
, bison
, flex
, openssl
, elfutils
, perl
, python3
, rsync
, gnused
, gawk
, cpio
, ... # linuxPackagesFor calls this with extra args (e.g. `features`) that
      # we don't use but must accept.
}:

let
  kernelVersion = "6.6.98";
  bspVersion = "cubie-aiot-v1.4.8";

  # Pinned to the branch HEAD commits as of 2026-07-02. Branches
  # (allwinner-aiot-linux-6.6 / cubie-aiot-v1.4.8) move over time, so a
  # concrete commit is used for reproducibility - bump these (and the
  # sha256 hashes below) deliberately when a kernel/BSP update is wanted.
  kernelRev = "b478ce0e9db225eb4a33d83e49a9a76c3ac9d438";
  bspRev = "eaea60ad7c058ae347eeffacf715bc5d539850c2";

  octaneosCommit = "cd24480c308db02d0c219453edd7f7df81ff9766";
  octaneosRaw = path: "https://raw.githubusercontent.com/GameOctane/OctaneOS/${octaneosCommit}/${path}";

  kernelSrc = fetchFromGitHub {
    owner = "radxa";
    repo = "kernel";
    rev = kernelRev;
    sha256 = "sha256-tKIRse82T8lcJWtmKRxlt6jttrvT8KgcjQWHecrGhyo=";
  };

  bspSrc = fetchFromGitHub {
    owner = "radxa";
    repo = "allwinner-bsp";
    rev = bspRev;
    sha256 = "sha256-PZnZ/FgYI4C8V5o5ucacGsLEnLD/48ccco6o4LwkoH0=";
  };

  # Board DTS is vendored locally (see ./sun60i-a733-cubie-a7s.dts) since it
  # is small, plain text, and originates from OctaneOS (commit pinned above)
  # rather than from either the Radxa kernel or BSP repo.
  boardDts = ./sun60i-a733-cubie-a7s.dts;
  defconfigBase = ./linux-defconfig.config;
  defconfigFragment = ./linux-defconfig-fragment.config;

  # NixOS's kernel.nix module (and various other nixpkgs modules) expect
  # `kernel.config` to be an object with isYes/isModule/isSet/etc. helper
  # methods (see pkgs/os-specific/linux/kernel/build.nix), not just a plain
  # "CONFIG_X=y" style attrset. We approximate this at eval time by reading
  # our own vendored base defconfig + fragment (fragment wins on conflict) -
  # this is NOT byte-identical to the final .config after `merge_config.sh`
  # + `olddefconfig` resolve dependent options at build time, but is
  # accurate for the same options those two source files already set
  # explicitly, which covers everything eval-time NixOS module code
  # actually queries (BLK_DEV_INITRD, MODULES, DEVTMPFS, etc.).
  readConfigFile =
    configFile:
    let
      matchLine =
        line:
        let
          match = builtins.match "(CONFIG_[^=]+)=([ym])" line;
        in
        lib.optional (match != null) {
          name = builtins.elemAt match 0;
          value = builtins.elemAt match 1;
        };
    in
    lib.listToAttrs (lib.concatMap matchLine (lib.splitString "\n" (builtins.readFile configFile)));

  configValues = (readConfigFile defconfigBase) // (readConfigFile defconfigFragment);

  kernelConfig =
    let
      attrName = attr: "CONFIG_" + attr;
    in
    rec {
      isSet = attr: builtins.hasAttr (attrName attr) configValues;
      getValue = attr: if isSet attr then configValues.${attrName attr} else null;
      isYes = attr: (getValue attr) == "y";
      isNo = attr: (getValue attr) == "n";
      isModule = attr: (getValue attr) == "m";
      isEnabled = attr: (isModule attr) || (isYes attr);
      isDisabled = attr: (!(isSet attr)) || (isNo attr);
    }
    // configValues;

  # Minimal headless patch set - see file header for what's deliberately
  # excluded (DP-Alt-Mode workarounds, xpad fix).
  patches = [
    ./patches/0001-cpufreq-sun50i-add-sun60i-a733-match.patch
    ./patches/1001-drivers-usb-Add-et7304-driver.patch
    ./patches/1004-Add-tcpci_husb311.c.patch
    ./patches/1005-tcpm-emit-state-machine-to-kernel-log.patch
    # Not part of OctaneOS's 1006-1012 DP-Alt-Mode series (all deferred to
    # Phase 6). This is our own fix for a real boot hang on headless setups:
    # sunxi_drm_bind() calls commit_init_connecting() unconditionally even
    # when no display was detected at boot, which hangs inside
    # drm_atomic_commit() on an empty atomic state. See patch body for the
    # full root-cause writeup.
    #
    # NOTE: as of this defconfig fragment's CONFIG_AW_DRM=n, sunxi_drm_drv.c
    # is no longer compiled into the kernel at all (see the "DRM/KMS display
    # stack — INTENTIONALLY DISABLED" block at the bottom of
    # linux-defconfig-fragment.config for the full reason: this patch alone
    # fixed one vendor DRM hang but a second, unresolved eDP-AUX-retry hang
    # was hit right after it, so the whole DRM/eDP/HDMI chain was disabled
    # instead of chasing a 3rd hand patch). This patch is kept here as a
    # harmless no-op (it still applies cleanly to the source tree, it just
    # patches a file that Kconfig now excludes from the build) so a future
    # person/agent re-enabling CONFIG_AW_DRM for the Phase 6 DP-Alt-Mode
    # stretch goal gets this fix "for free" - but be aware you will very
    # likely still need to find and fix the second eDP-AUX hang before
    # display output actually works end-to-end headed.
    ./patches/1013-sunxi-drm-skip-commit-init-connecting-when-headless.patch
    # patches/1015-*.patch (two attempts, both REVERTED - do NOT re-add
    # either without a fundamentally new hypothesis):
    #   v1 (enable-pclk-gmac0-mbus-clock.patch): enabling CLK_GMAC0_MBUS via
    #   a new "pclk" clk_get+enable made things WORSE - boot hung ~0.6s in
    #   (inside clk_prepare_enable() itself, a genuine HW MMIO/bus stall on
    #   that CCU gate, not a software error).
    #   v2 (deassert-axi-bus-reset.patch): added a devm_reset_control_get for
    #   the previously-unfetched "stmmaceth"/RST_BUS_GMAC0_AXI reset. This
    #   patch's OWN "Get axi reset failed" error fired at boot (the reset
    #   framework genuinely errored on this brand-new SoC, not just
    #   "property absent"), so sunxi_dwmac_probe() failed OUTRIGHT and
    #   NEVER reached phylink_start()/stmmac_enable_all_dma_irq() at all -
    #   yet the system STILL hung at the exact same relative point in boot
    #   (immediately after the MMC RTO retry-give-up burst). This is
    #   CONCLUSIVE PROOF the entire dwmac-sunxi/Ethernet hang hypothesis
    #   chain (pclk clock, AXI reset, the original phylink diagnostic
    #   findings) was a RED HERRING - Ethernet never even needs to
    #   initialize for the hang to occur. The real culprit is almost
    #   certainly the MMC subsystem itself or whatever kernel driver-init
    #   step runs immediately after MMC probe completes. Next investigation
    #   should target that, e.g. via `initcall_debug` kernel param or by
    #   temporarily raising boot.consoleLogLevel to see hidden INFO/DEBUG
    #   output between "retry:give up" and the hang point.
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "linux-cubie-a7s";
  version = "${kernelVersion}-${bspVersion}";

  nativeBuildInputs = [
    bc
    bison
    flex
    openssl
    elfutils
    perl
    python3
    rsync
    gnused
    gawk
    cpio
  ];

  # Custom unpack: assemble the merged kernel+BSP source tree (mirrors
  # OctaneOS's setup-kernel-66.sh steps 1-2 + 3-8) before the generic
  # patchPhase applies the 4 patches above.
  unpackPhase = ''
    runHook preUnpack

    cp -r ${kernelSrc} kernel-src
    chmod -R u+w kernel-src
    cd kernel-src

    echo "Merging allwinner-bsp (${bspVersion}) into bsp/ ..."
    cp -r ${bspSrc} bsp
    chmod -R u+w bsp

    # Step 3 (setup-kernel-66.sh): stub sunxi-autogen.h. The real SDK
    # generates AW_BSP_VERSION from `git rev-parse --short HEAD`; we hardcode
    # a fixed, descriptive string instead since bsp/ here isn't a git repo.
    cat > bsp/include/sunxi-autogen.h <<EOF
    /* SPDX-License-Identifier: GPL-2.0 */
    /* Generated by linux-cubie-a7s.nix (Nix build, not the Allwinner SDK) */
    #ifndef __SUNXI_AUTOGEN_H__
    #define __SUNXI_AUTOGEN_H__
    #define AW_BSP_VERSION "${bspVersion}-${builtins.substring 0 8 bspRev}"
    #endif /* __SUNXI_AUTOGEN_H__ */
    EOF

    # NOTE: Step 4 (the $(BSP_TOP) Kconfig sed-fixup) is intentionally NOT
    # done here. linux_patches_66/1001 (et7304 driver) adds a new Kconfig
    # source line using the literal "$(BSP_TOP)..." text as patch context,
    # so the fixup must run AFTER patchPhase (see postPatch below) or the
    # patch's context/added lines no longer match the pre-sed BSP source
    # and `patch` fails ("Hunk FAILED"). Applying it post-patch still
    # catches every $(BSP_TOP) reference, including ones patches add.

    # Step 5: drop bsp/Makefile's nand/ and gpu/ subdirs - both use
    # out-of-tree build conventions incompatible with an in-tree kernel
    # build. NAND is unused on this MMC-only board; the GPU's pvrsrvkm.ko
    # is out of scope for this headless-only build (deferred to a future
    # display bring-up phase, built out-of-tree against $out/lib/modules
    # the same way OctaneOS's post-build.sh does).
    sed -i '/obj-y += modules\/nand\//d' bsp/Makefile
    sed -i '/obj-y += modules\/gpu\//d'  bsp/Makefile

    # BSP USB host Makefile includes headers via drivers/usb/sunxi_usb -
    # bridge it into the mainline drivers/usb/ tree. NOTE: the symlink
    # itself lives at kernel-src/drivers/usb/sunxi_usb, so its relative
    # target must climb back up to kernel-src/ with "../../" (not "../") to
    # correctly reach kernel-src/bsp/drivers/usb/sunxi_usb - a single ".."
    # would wrongly resolve to kernel-src/drivers/bsp/... (nonexistent),
    # which broke BSP's `#include <../sunxi_usb/include/...>` headers.
    ln -sfn ../../bsp/drivers/usb/sunxi_usb drivers/usb/sunxi_usb

    # Step 6: SoC-level DTSI files only exist in the BSP tree.
    cp bsp/configs/linux-6.6/sun60iw2p1.dtsi arch/arm64/boot/dts/allwinner/
    cp bsp/configs/linux-6.6/sun60iw2p1-cpu-vf.dtsi arch/arm64/boot/dts/allwinner/

    # Step 7: Allwinner-specific dt-bindings headers, no-clobber so mainline
    # headers of the same name (if any) take precedence.
    cp -rn bsp/include/dt-bindings/. include/dt-bindings/ || true

    # Step 8: board DTS + DTB Makefile entry.
    cp ${boardDts} arch/arm64/boot/dts/allwinner/sun60i-a733-cubie-a7s.dts
    if ! grep -q "sun60i-a733-cubie-a7s.dtb" arch/arm64/boot/dts/allwinner/Makefile; then
      echo 'dtb-$(CONFIG_ARCH_SUNXI) += sun60i-a733-cubie-a7s.dtb' >> arch/arm64/boot/dts/allwinner/Makefile
    fi

    cd ..
    sourceRoot=kernel-src

    runHook postUnpack
  '';

  inherit patches;

  # Step 4 (deferred from unpackPhase, see note above): BSP Kconfig files
  # reference $(BSP_TOP) which the Allwinner SDK passes as BSP_TOP=bsp/ at
  # build time; a plain kernel Makefile build never sets it, so Kconfig
  # fails with "can't open file". Replace with the literal path (BSP is
  # always merged into bsp/ here). Runs after patches are applied so it
  # also fixes up any $(BSP_TOP) references the patches themselves added.
  postPatch = ''
    find bsp -name 'Kconfig*' -exec grep -l '\$(BSP_TOP)' {} \; \
      | xargs -r sed -i 's|\$(BSP_TOP)|bsp/|g'
  '';

  # Merge the base Radxa defconfig with OctaneOS's A733-specific fragment
  # using the kernel's own merge_config.sh (standard technique), then
  # resolve any resulting new/dependent options non-interactively.
  #
  # NOTE: the fragment enables CONFIG_AW_WAKEUPGEN / CONFIG_AW_SUN8I_NMI,
  # which are NOT optional - without them, pinctrl/GPIO/TWI/MMC probing
  # hangs indefinitely on this SoC (documented in the fragment itself).
  configurePhase = ''
    runHook preConfigure

    export ARCH=arm64
    export KCONFIG_NOTIMESTAMP=1

    bash scripts/kconfig/merge_config.sh -m -O . \
      ${defconfigBase} ${defconfigFragment}
    mv .config.tmp .config 2>/dev/null || true
    make ARCH=arm64 olddefconfig

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    make ARCH=arm64 -j"$NIX_BUILD_CORES" Image dtbs modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out $out/dtbs/allwinner
    cp arch/arm64/boot/Image $out/Image
    # Real, fully Kconfig-resolved .config (post merge_config.sh +
    # olddefconfig) - see passthru.configfile below for why this needs to
    # exist as a build output rather than just referencing the source
    # fragment file.
    cp .config $out/config
    # Installed under dtbs/allwinner/ to match the layout NixOS's
    # hardware.deviceTree module expects when scanning ''${kernel}/dtbs/**.
    cp arch/arm64/boot/dts/allwinner/sun60i-a733-cubie-a7s.dtb $out/dtbs/allwinner/sun60i-a733-cubie-a7s.dtb

    make ARCH=arm64 modules_install \
      INSTALL_MOD_PATH=$out \
      INSTALL_MOD_STRIP=1

    # `make modules_install` creates lib/modules/${kernelVersion}/{build,source}
    # symlinks pointing into the transient Nix build sandbox directory, which
    # would be dangling once the sandbox is cleaned up (fails Nix's
    # noBrokenSymlinks fixup check). Remove them; the pieces needed for
    # out-of-tree module builds (.config/Module.symvers) are copied to
    # $out/build below instead.
    rm -f "$out/lib/modules/${kernelVersion}/build"
    rm -f "$out/lib/modules/${kernelVersion}/source"

    # Full configured+built source tree for out-of-tree module builds (e.g.
    # the AIC8800 USB WiFi driver, Phase 5). Since this is a custom
    # single-output kernel derivation (not nixpkgs' usual multi-output
    # buildLinux, which has a dedicated `.dev` output for exactly this
    # purpose), we mirror that convention manually here: copy the whole
    # post-build kernel-src working directory (Makefile, Kconfig, .config,
    # Module.symvers, scripts/, include/{config,generated}/,
    # arch/arm64/include/, etc.) into $out/build so `make -C $out/build
    # M=$PWD modules` works for external modules against this exact kernel.
    # This significantly increases $out's size but is the standard/only
    # robust way to support out-of-tree modules without guessing which
    # subset of the tree is load-bearing for a given module's build.
    mkdir -p $out/build
    cp -a . $out/build/

    # The BSP source tree ships a prebuilt ramfs skeleton under
    # bsp/ramfs/ramfs_aarch64/{etc,dev,var}/* containing dangling symlinks
    # like /etc/resolv.conf -> /tmp/resolv.conf and /dev/log -> /tmp/log.
    # These are meant to point at a REAL /tmp at runtime inside that
    # ramdisk image, not at anything that exists in our build sandbox/Nix
    # store - copying the tree wholesale via `cp -a` above pulls these in
    # verbatim, which fails nixpkgs' standard fixupPhase noBrokenSymlinks
    # check ("found N dangling symlinks"). They're irrelevant to building
    # out-of-tree kernel modules (the actual purpose of $out/build), so
    # just strip any dangling symlinks from the exported tree entirely.
    find $out/build -xtype l -delete

    runHook postInstall
  '';

  # Kernel builds are extremely slow to sandbox-diff; nothing else touches
  # $out concurrently so this is safe.
  dontStrip = true;

  passthru = rec {
    inherit kernelVersion bspVersion kernelRev bspRev;
    modDirVersion = kernelVersion;
    version = kernelVersion;
    baseVersion = kernelVersion;
    # Presence of `features` (regardless of contents) makes NixOS's
    # kernel.nix module skip its `config.boot.kernelPackages.kernel.config`
    # assertion path entirely (see nixos/modules/system/boot/kernel.nix,
    # "nixpkgs kernels are assumed to have all required features"). An
    # empty set means no optional feature (efiBootStub, etc.) is assumed
    # present, which is correct: this board boots via U-Boot
    # generic-extlinux-compatible, not any UEFI/systemd-boot path.
    features = { };
    # pkgs/os-specific/linux/cpupower's derivation does
    # `inherit (kernel) version src patches;` - it builds the
    # tools/power/cpupower userspace CLI straight out of a kernel source
    # tree. This gets pulled in as soon as `powerManagement.cpuFreqGovernor`
    # is set (via `config.boot.kernelPackages.cpupower`, see
    # nixos/modules/tasks/cpu-freq.nix), which fails with "attribute 'src'
    # missing" without this. Our custom multi-repo-merge kernel has no
    # single canonical `src` (unpackPhase merges kernelSrc + bspSrc
    # directly via Nix string interpolation, never through a `src`
    # derivation attribute - see unpackPhase above), but tools/power/cpupower
    # only exists in the plain radxa/kernel tree, so exposing kernelSrc here
    # (unrelated to bspSrc) satisfies cpupower's `inherit` without affecting
    # our own build in any way.
    src = kernelSrc;
    # Standard nixpkgs kernel-package passthru interface (see
    # pkgs/os-specific/linux/kernel/build.nix's own `passthru` block) -
    # `linuxPackagesFor` and various nixpkgs modules (module-building
    # packages, NixOS's kernel.nix, sd-image build) expect these to exist.
    kernelOlder = lib.versionOlder baseVersion;
    kernelAtLeast = lib.versionAtLeast baseVersion;
    isZen = false;
    isHardened = false;
    isLibre = false;
    isXen = true;
    withRust = kernelConfig.isYes "RUST";
    isModular = kernelConfig.isYes "MODULES";
    config = kernelConfig;
    # Point at the REAL post-merge_config.sh/post-olddefconfig .config
    # (installed to $out/config below), not the raw pre-merge fragment.
    # nixos/modules/config/sysctl.nix greps this file at build time for
    # CONFIG_ARCH_MMAP_RND_BITS_MAX/CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MAX,
    # which are Kconfig-computed arch defaults never spelled out literally
    # in our defconfig/fragment - only the fully resolved .config has them.
    configfile = "${finalAttrs.finalPackage}/config";
    kernelPatches = [ ];
    moduleBuildDependencies = [ ];
    commonMakeFlags = [ "ARCH=arm64" ];
  };

  meta = with lib; {
    description = "Minimal headless Linux 6.6 + Radxa allwinner-bsp kernel for Radxa Cubie A7S (A733/sun60iw2)";
    license = licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
})
