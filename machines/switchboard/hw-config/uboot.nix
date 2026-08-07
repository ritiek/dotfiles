
# Vendored from https://github.com/patryk4815/nixos-cubie-a5e
# (modules/uboot.nix)
{ pkgs }:
let
  armTrustedFirmwareSun55i = pkgs.buildPackages.buildArmTrustedFirmware rec {
    platform = "sun55i_a523";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/debug/bl31.bin" ];
    extraMakeFlags = [ "DEBUG=1" ];
    src = pkgs.fetchFromGitHub {
      owner = "jernejsk";
      repo = "arm-trusted-firmware";
      rev = "e019f64d91ff7c2dfbbfe7f76a14f240761b9edc"; # branch: a523-v4
      hash = "sha256-c42bWMYTlhNn4Byr3gaptkgatHv2DrRtXGj6GH7IbUg=";
    };
  };

  mkUboot = defconfig: extraPatches: extraConfig: pkgs.buildPackages.buildUBoot {
    inherit defconfig extraPatches;
    extraMeta.platforms = [ "aarch64-linux" ];
    env.BL31 = "${armTrustedFirmwareSun55i}/bl31.bin";
    extraConfig = ''
      CONFIG_CMD_MEMTEST=y
      CONFIG_MTD=y
      CONFIG_SPI_FLASH_WINBOND=y
      CONFIG_SPI_FLASH_XMC=y
      CONFIG_SPI=y
      CONFIG_SPL_SPI_SUNXI=y
      CONFIG_PCI=y
      CONFIG_PCI_INIT_R=y
      CONFIG_PCIE_DW_COMMON=y
      CONFIG_PCIE_SUN55I_RC=y
      CONFIG_PHY_SUN55I_PCIE_USB3=y
      CONFIG_NVME_PCI=y
      CONFIG_CMD_NVME=y
      CONFIG_CMD_PCI=y
      CONFIG_USB_STORAGE=y
      CONFIG_LOGLEVEL=7
    '' + extraConfig;
    filesToInstall = [ "u-boot-sunxi-with-spl.bin" ];
  };

  spiNorImageSize = 16; # MiB

  mkSpiNorImage = name: uboot: pkgs.buildPackages.runCommand "${name}-spinor.img" {} ''
    dd if=/dev/zero of=$out bs=1M count=${toString spiNorImageSize}
    dd if=${uboot}/u-boot-sunxi-with-spl.bin of=$out bs=1k conv=notrunc
  '';

  vendor = pkgs.buildPackages.stdenv.mkDerivation {
    pname = "u-boot-radxa-cubie-a5e";
    version = "2018.07-17";
    src = pkgs.fetchurl {
      url = "https://github.com/radxa-pkg/u-boot-aw2501/releases/download/2018.07-17/u-boot-aw2501_2018.07-17_all.deb";
      hash = "sha256-hM2IV20KDh8TR8v0cyUe4f1RFk5E8sOh+OV/v0pyuok=";
    };
    nativeBuildInputs = [ pkgs.buildPackages.dpkg ];
    unpackPhase = "dpkg-deb -x $src .";
    installPhase = ''
      mkdir -p $out
      cp usr/lib/u-boot/radxa-cubie-a5e/boot0_sdcard.bin $out/
      cp usr/lib/u-boot/radxa-cubie-a5e/boot0_spinor.bin $out/
      cp usr/lib/u-boot/radxa-cubie-a5e/boot_package.fex $out/
      cp usr/lib/u-boot/radxa-cubie-a5e/sys_partition_nor.bin $out/
    '';
  };

  spiPatches = [
    ./patches/uboot/a523-spi-1-driver.patch
    ./patches/uboot/a523-spi-2-spl-cleanup.patch
    ./patches/uboot/a523-spi-dts.patch
    ./patches/uboot/armbian-pcie-1-dw-driver.patch
    ./patches/uboot/armbian-pcie-2-combophy.patch
    ./patches/uboot/armbian-pcie-3-clocks.patch
    ./patches/uboot/armbian-pcie-4-dtsi-nodes.patch
    ./patches/uboot/armbian-pcie-5-cubie-a5e-dts.patch
    # sunxi's BOOT_TARGET_DEVICES has no NVMe entry, so boot_targets ends up as
    # "fel mmc_auto usb0 pxe dhcp" and NVMe is never tried. distro_bootcmd
    # already supports NVMe generically (gated on CONFIG_NVME).
    ./patches/uboot/a523-nvme-boot-target.patch
  ];

  mainline-1gb = mkUboot "radxa-cubie-a5e_defconfig" spiPatches ''
    CONFIG_DRAM_SUNXI_TPR2=0x1f0b0503
    CONFIG_DRAM_SUNXI_TPR6=0x3a000000
    CONFIG_DRAM_CLK=720
    CONFIG_DRAM_SUNXI_TPR10=0x802f3333
    CONFIG_DRAM_SUNXI_TPR11=0xc0c0bbbf
    CONFIG_DRAM_SUNXI_TPR12=0x35352f31
  '';
  mainline-2gb = mkUboot "radxa-cubie-a5e_defconfig" spiPatches "";
in {
  inherit mainline-1gb mainline-2gb;

  vendor = pkgs.buildPackages.runCommand "cubie-a5e-vendor-uboot" {} ''
    mkdir -p $out
    # boot0 at offset 0 → maps to sector 256 (128KB) when dd'd with bs=1k seek=128
    # boot_package at relative sector 24320 (= 24576 - 256)
    dd if=${vendor}/boot0_sdcard.bin of=$out/u-boot-sunxi-with-spl.bin bs=512 conv=notrunc
    dd if=${vendor}/boot_package.fex of=$out/u-boot-sunxi-with-spl.bin bs=512 seek=$((24576 - 256)) conv=notrunc
  '';

  spinor-vendor = pkgs.buildPackages.runCommand "cubie-a5e-vendor-spinor.img" {} ''
    dd if=/dev/zero of=$out bs=1M count=${toString spiNorImageSize}
    dd if=${vendor}/boot0_spinor.bin of=$out bs=512 conv=notrunc
    dd if=${vendor}/boot_package.fex of=$out bs=512 seek=128 conv=notrunc
    dd if=${vendor}/sys_partition_nor.bin of=$out bs=512 seek=2016 conv=notrunc
  '';
  spinor-1gb = mkSpiNorImage "cubie-a5e-1gb" mainline-1gb;
  spinor-2gb = mkSpiNorImage "cubie-a5e-2gb" mainline-2gb;
}
