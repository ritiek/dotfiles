# Rockchip BSP 6.1 kernel (Armbian's rk-6.1-rkr7.2 tree + Armbian's config).
# Mainline has no RK3566 video encoder/HEVC decoder or NPU driver; this tree
# has MPP (VPU), RGA and RKNPU. The GPU stays on panfrost (Armbian builds no
# Mali kbase driver for Bifrost).
{ pkgs, lib, ... }:

let
  stdenv = pkgs.gcc13Stdenv;
  version = "6.1.172";

  src = pkgs.fetchFromGitHub {
    owner = "armbian";
    repo = "linux-rockchip";
    rev = "16840d33949398aeb0f6894277c53293e31d2325"; # rk-6.1-rkr7.2
    hash = "sha256-WA2QHNdBJRNFWjcv8WMpMbTVnPw0Hr3BuedKvl7r4Bk=";
  };

  armbianConfig = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/armbian/build/f93df53dc70b85762af51f9cec5219d1f84b7761/config/kernel/linux-rk35xx-vendor.config";
    hash = "sha256-feH1HqeMPRj89aD4j/7SbIAyWVq94sgfdqAul+qBwrY=";
  };

  # Later lines override Armbian's.
  configfile = stdenv.mkDerivation {
    pname = "linux-rk35xx-vendor-config";
    inherit version src;
    nativeBuildInputs = with pkgs; [ bison flex perl bc ];
    buildPhase = ''
      cat ${armbianConfig} - > arch/arm64/configs/nixos_defconfig <<'EOF'
      # CONFIG_WERROR is not set
      # In-tree aic8800 clashes with the out-of-tree driver (aic8800.nix).
      # CONFIG_AIC_WLAN_SUPPORT is not set
      CONFIG_DEBUG_INFO_NONE=y
      # CONFIG_DEBUG_INFO_BTF is not set
      # zram is used instead.
      # CONFIG_ZSWAP_DEFAULT_ON is not set
      EOF
      make ARCH=arm64 nixos_defconfig
    '';
    installPhase = "cp .config $out";
  };

  kernel = pkgs.linuxManualConfig {
    inherit src version stdenv configfile;
    allowImportFromDerivation = true;
  };
in
{
  boot.kernelPackages = pkgs.linuxPackagesFor kernel;
  # The sd-image profile lists generic initrd modules (vc4, sun4i, pata_*) the vendor config lacks.
  boot.initrd.allowMissingModules = true;

  hardware.deviceTree = {
    # Ship the vendor dtb under the mainline name U-Boot already loads via
    # FDTDIR. Setting `name` instead would rewrite FDT for every extlinux
    # entry, breaking older mainline generations that lack the vendor name.
    dtbSource = pkgs.runCommand "rk3566-radxa-zero-3w-vendor-dtb" { } ''
      install -D ${kernel}/dtbs/rockchip/rk3566-radxa-zero3.dtb $out/rockchip/rk3566-radxa-zero-3w.dtb
    '';
    # NPU is disabled in the board DT. Port of radxa-overlays'
    # rk3568-npu-enable.dts.
    overlays = [{
      name = "rk3566-npu-enable";
      dtsText = ''
        /dts-v1/;
        /plugin/;
        / { compatible = "rockchip,rk3566"; };
        &bus_npu { bus-supply = <&vdd_logic>; pvtm-supply = <&vdd_cpu>; status = "okay"; };
        &rknpu { memory-region = <&rknpu_reserved>; status = "okay"; };
        &rknpu_mmu { status = "okay"; };
        &reserved_memory {
          rknpu_reserved: rknpu {
            compatible = "shared-dma-pool";
            inactive;
            reusable;
            size = <0x0 0x8000000>;
            alignment = <0x0 0x1000>;
          };
        };
      '';
    } {
      # The shared Zero 3 DT enables the 3E's ethernet; the 3W has none.
      name = "rk3566-zero3w-no-gmac";
      dtsText = ''
        /dts-v1/;
        /plugin/;
        / { compatible = "rockchip,rk3566"; };
        &gmac1 { status = "disabled"; };
      '';
    }];
  };

  # MPP (VPU) and RGA device access, from Jellyfin's Rockchip docs.
  services.udev.extraRules = ''
    KERNEL=="mpp_service", MODE="0660", GROUP="video"
    KERNEL=="rga", MODE="0660", GROUP="video"
    SUBSYSTEM=="dma_heap", MODE="0666", GROUP="video"
  '';

  # VPU clocks idle at 297 MHz under the default governor; performance
  # gives about 25% more transcode throughput.
  systemd.tmpfiles.rules = [
    "w- /sys/class/devfreq/fdf40000.rkvenc/governor - - - - performance"
    "w- /sys/class/devfreq/fdf80200.rkvdec/governor - - - - performance"
  ];

  # GPU: panfrost + Mesa, OpenCL via Rusticl.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.mesa.opencl ];
  };
  environment.variables.RUSTICL_ENABLE = "panfrost";

  # `sudo rk-top`: live NPU/GPU/VPU/RGA load. nvtop can't see these: the
  # vendor 6.1 kernel has no DRM fdinfo stats.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "rk-top";
      runtimeInputs = with pkgs; [ coreutils gawk gnused ncurses ];
      text = ''
        df=/sys/class/devfreq
        mhz() { echo "$(( $(cat "$df/$1/cur_freq") / 1000000 )) MHz"; }
        echo 1000 > /proc/mpp_service/load_interval
        while :; do
          out=$(
            printf '%-8s %8s %9s\n' UNIT LOAD CLOCK
            printf '%-8s %8s %9s\n' NPU "$(sed 's/.*: *//' /sys/kernel/debug/rknpu/load)" "$(mhz fde40000.npu)"
            printf '%-8s %8s %9s\n' GPU "$(cut -d@ -f1 $df/fde60000.gpu/load)%" "$(mhz fde60000.gpu)"
            printf '%-8s %8s %9s\n' RAM-BUS "$(cut -d@ -f1 $df/dmc/load)%" "$(mhz dmc)"
            printf '%-8s %8s\n' RGA "$(awk '$1 == "load" {print $3}' /sys/kernel/debug/rkrga/load)"
            awk '{sub(/^[^.]*\./, "", $1); printf "%-8s %8s\n", toupper($1), $3}' /proc/mpp_service/load
            for z in /sys/class/thermal/thermal_zone*; do
              printf '%-8s %7sC\n' "$(sed 's/-thermal//' "$z/type")" "$(( $(cat "$z/temp") / 1000 ))"
            done
          )
          clear; echo "$out"; sleep 1
        done
      '';
    })
  ];
}
