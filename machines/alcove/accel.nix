# GPU (PowerVR BXM-4-64), VPU (cedar VE) and NPU (Vivante VIP, VIPLite v2)
# for the Cubie A7S. Kernel side lives in linux-defconfig-fragment.config
# ("Hardware accelerators" block); sunxi-ve and vipcore are built in-tree,
# pvrsrvkm is built here against the kernel's $out/build tree.
#
# Userspace is Allwinner's closed blobs, the same ones Radxa/Armbian ship:
# - GPU: DDK 24.2@6603887 (must match the kernel DDK in bsp/modules/gpu/img-bxm)
# - VPU: libcedarc 2.0 + gst-omx (OpenMAX) plugin
# - NPU: VIPLite 2.0 (libNBGlinker/libVIPhal) + Radxa's vpm_run test tool
#
# Quick checks once booted:
#   clinfo -l; vulkaninfo --summary
#   gst-launch-1.0 videotestsrc num-buffers=300 ! omxh264videoenc ! omxh264dec ! fakesink
#   cd /tmp && vpm_run -s /run/current-system/sw/share/vpm_run/sample.txt -l 1
{ config, lib, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  # Debian bullseye packages from Allwinner's sun60iw2 rootfs (what Armbian uses).
  rootfs = "https://raw.githubusercontent.com/orangepi-xunlong/rk-rootfs-build/7b6d78d4f5eaefd5456777fbea5057a0876e8f4d/bullseye";
  aiSdk = "https://raw.githubusercontent.com/ZIFENG278/ai-sdk/fc90006d0f6569da2f6726c2d8395877686f5aca";
  fetch = url: sha256: pkgs.fetchurl { inherit url sha256; };

  pvrsrvkm = pkgs.stdenv.mkDerivation {
    pname = "pvrsrvkm";
    version = "24.2.6603887-${kernel.version}";
    src = "${kernel}/build/bsp/modules/gpu/img-bxm/linux/rogue_km";
    nativeBuildInputs = with pkgs; [ bc bison flex openssl elfutils perl python3 which ];
    hardeningDisable = [ "pic" ];

    # GNU make >= 4.4 rejects the DDK's `.SECONDARY:` (Radxa's aw-drivers-dkms
    # carries the same fix).
    postPatch = ''
      grep -rl '^\.SECONDARY:' build/linux | xargs sed -i 's/^\.SECONDARY:/.NOTINTERMEDIATE:/'
      patchShebangs .
    '';

    # sunxi_linux/Makefile defaults to Allwinner's LICHEE toolchain paths and
    # /usr/bin/gcc; point it at stdenv's native compiler instead.
    makeFlags = [
      "-C" "build/linux/sunxi_linux"
      "KERNELDIR=${kernel}/build"
      "BUILD=release"
      "KERNEL_CC=cc" "KERNEL_LD=ld" "KERNEL_NM=nm" "KERNEL_OBJCOPY=objcopy"
      "HOST_CC=cc" "HOST_CXX=c++"
      "SUPPORT_LINUX_DVFS=1"
    ];

    installPhase = ''
      install -Dm444 binary_sunxi_linux_nulldrmws_release/target_aarch64/kbuild/pvrsrvkm.ko \
        -t $out/lib/modules/${kernel.modDirVersion}/extra
    '';
  };

  # Mesa-PVR (EGL/GLES/GBM), Vulkan, OpenCL and the GPU firmware.
  img-bxm = pkgs.stdenv.mkDerivation {
    pname = "img-bxm";
    version = "24.2.6603887";
    src = fetch "${rootfs}/xserver/xserver-xorg-img-bxm_1.21.1-2_arm64.deb"
      "0fjc63ixsw5bar9saxhvzv2m06whhvm0aybzp6jl1smx3bdhdrn8";
    nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook ];
    buildInputs = with pkgs; [ stdenv.cc.cc.lib libdrm expat zlib libx11 libxcb libxshmfence systemdLibs ];
    # The blobs dlopen each other by bare soname.
    appendRunpaths = [ "${placeholder "out"}/lib" ];
    # rgx.fw is a MIPS firmware ELF; strip would mangle it.
    dontStrip = true;

    # Skips Xorg, its modules, the vendor Vulkan loader and libOpenCL symlinks
    # (nixpkgs provides the loaders via /run/opengl-driver ICD files).
    installPhase = ''
      mkdir -p $out/lib/dri $out/share/vulkan/icd.d $out/etc/OpenCL/vendors
      cp -a lib/firmware $out/lib/
      cp -a usr/lib/lib*_PVR_MESA.so* usr/lib/lib{glslcompiler,pvr_dri_support,PVROCL,PVRScopeServices,srv_um,sutu_display,ufwriter,usc,VK_IMG}.so* $out/lib/
      cp -a usr/local/lib/lib{EGL,GLESv1_CM,GLESv2,gbm,glapi,pvr_mesa_wsi}.so* $out/lib/
      cp -a usr/local/lib/dri/pvr_dri.so $out/lib/dri/

      echo '{"file_format_version":"1.0.0","ICD":{"library_path":"'$out'/lib/libVK_IMG.so.1","api_version":"1.3.277"}}' \
        > $out/share/vulkan/icd.d/img_icd.json
      echo $out/lib/libPVROCL.so.1 > $out/etc/OpenCL/vendors/pvr.icd
    '';
  };

  # cedar VE codec libraries + OpenMAX IL components + GStreamer omx plugin.
  cedarc = pkgs.stdenv.mkDerivation {
    pname = "cedarc";
    version = "2.0.0";
    srcs = [
      (fetch "${rootfs}/libcedarc/libcedarc-dev_2.0.0_arm64.deb"
        "139jny4dnzpymbqd804sxl7wy9ln8jgzagzf4a12adpsjg88z4f1")
      (fetch "${rootfs}/gst-omx-generic1.0/gstreamer1.0-omx-allwinner_1.18.3-1.1_arm64.deb"
        "19nwbjcp4hykiyf3dkaf0psa20vsf7d2c87xqlzv9hkxqa2l18hl")
      (fetch "${rootfs}/gst-omx-generic1.0/gstreamer1.0-omx-allwinner-config_1.18.3-1.1_arm64.deb"
        "07gri5d21cr022f8b90i8a03zymp0idkjrzw45l7dd3xb8sj36c7")
    ];
    unpackPhase = "for s in $srcs; do dpkg-deb -x $s .; done";
    nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook ];
    buildInputs = with pkgs.gst_all_1; [ gstreamer gst-plugins-base ];
    # libOmxCore/libvideoengine dlopen codec plugins by bare name.
    appendRunpaths = [ "${placeholder "out"}/lib" ];

    installPhase = ''
      mkdir -p $out/lib/gstreamer-1.0 $out/bin $out/etc/xdg
      cp -a usr/lib/aarch64-linux-gnu/*.so $out/lib/
      # GStreamer derives the entry symbol from the filename; the blob exports
      # gst_plugin_omx_get_desc, so it must be called libgstomx.so.
      cp -a usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstomx-allwinner.so $out/lib/gstreamer-1.0/libgstomx.so
      cp -a usr/bin/vdecoderdemo $out/bin/
      cp -a etc/cedarc.conf $out/etc/
      # The plugin reads gstomx.conf from XDG config dirs.
      sed "s|/usr/lib/aarch64-linux-gnu/|$out/lib/|" etc/xdg/gstomx-allwinner.conf > $out/etc/xdg/gstomx.conf
    '';
  };

  # VIPLite 2.0 runtime + vpm_run with Radxa's A733 sample network.
  viplite = pkgs.stdenv.mkDerivation {
    pname = "viplite";
    version = "2.0";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildPhase = let v2 = "${aiSdk}/viplite-tina/lib/aarch64-none-linux-gnu/v2.0"; in ''
      install -Dm555 ${fetch "${v2}/libNBGlinker.so" "0rna92vxar0d2wv4xhn9ax2g5gpwxnqywdry8i6xsr80xnq4kw42"} $out/lib/libNBGlinker.so
      install -Dm555 ${fetch "${v2}/libVIPhal.so" "1whipd4drk4awawngzni26kxs9vjccfv5h5xiyv4yv5x4rxkbm9y"} $out/lib/libVIPhal.so
      install -Dm444 ${fetch "${v2}/inc/vip_lite.h" "0hfzv5hxa8bm943q2zgq30krgrln81hv1qmp2i7v6311hpwyizik"} $out/include/vip_lite.h
      install -Dm444 ${fetch "${v2}/inc/vip_lite_common.h" "13jil6qn3nrsrlx5867gg6rclp6dj4dwnkh7vqllgpknhdp221yq"} $out/include/vip_lite_common.h
      $CC -DSAVE_OUTPUT_TXT_FILE -DSHOW_TOP5 -DNPU_SW_VERSION=2 -o vpm_run \
        ${fetch "${aiSdk}/examples/vpm_run/vpm_run.c" "0wdf29axxfqa2c32dp6pvx3x0q4ry6xsvqz138kb5rcck7d1lzxr"} \
        -I$out/include -L$out/lib -lNBGlinker -lVIPhal -lm
    '';
    installPhase = let d = "$out/share/vpm_run"; in ''
      install -Dm555 vpm_run -t $out/bin
      install -Dm444 ${fetch "${aiSdk}/examples/vpm_run/operator/v3/network_binary.nb" "0pxrm5gm0750g5ll4bwsfl75cp356jfssvgg9v3xzr33r2ym03gw"} ${d}/network_binary.nb
      install -Dm444 ${fetch "${aiSdk}/examples/vpm_run/operator/input_0.dat" "1fgi08ali4dwcl7yrpp8k7n12gcz798yppwx5ibi9cvx0312536k"} ${d}/input_0.dat
      printf '[network]\n%s\n[input]\n%s\n' ${d}/network_binary.nb ${d}/input_0.dat > ${d}/sample.txt
    '';
  };
in
{
  boot.extraModulePackages = [ pvrsrvkm ];

  hardware.firmware = [ img-bxm ];
  hardware.graphics = {
    enable = true;
    package = img-bxm;
  };
  # modules/netbird.nix ties the GUI to hardware.graphics; alcove is headless.
  services.netbird.ui.enable = lib.mkForce false;

  environment.etc."cedarc.conf".source = "${cedarc}/etc/cedarc.conf";
  environment.etc."xdg/gstomx.conf".source = "${cedarc}/etc/xdg/gstomx.conf";
  environment.variables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0"
    (with pkgs.gst_all_1; [ gstreamer gst-plugins-base cedarc ]);

  services.udev.extraRules = ''
    SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"
    KERNEL=="cedar_dev*|sunxi_soc_info|vipcore", GROUP="video", MODE="0660"
  '';
  users.users.ritiek.extraGroups = [ "video" "render" ];

  environment.systemPackages = with pkgs; [
    clinfo
    vulkan-tools
    gst_all_1.gstreamer
    cedarc
    viplite
    # `sudo rk-top`: live GPU/NPU/VE load and clocks. GPU/NPU load come from
    # their drivers' own counters; VE has none, so it shows its IRQ rate
    # (roughly frames/s). Clocks are the real clock-tree rates.
    (pkgs.writeShellApplication {
      name = "rk-top";
      runtimeInputs = with pkgs; [ coreutils gawk gnused util-linux ];
      text = ''
        dbg=/sys/kernel/debug
        mountpoint -q $dbg || mount -t debugfs none $dbg
        df=/sys/class/devfreq
        clk=$dbg/clk
        mhz() { echo "$(( $(cat "$1") / 1000000 )) MHz"; }
        irqs() { awk -v n="$1" '$NF == n { s = 0; for (i = 2; i < NF - 3; i++) s += $i; print s }' /proc/interrupts; }
        dec=$(irqs cedar_dev); enc=$(irqs cedar_dev_ve2)
        while :; do
          sleep 1
          d=$(irqs cedar_dev); e=$(irqs cedar_dev_ve2)
          out=$(
            printf '%-9s %8s %9s\n' UNIT LOAD CLOCK
            printf '%-9s %8s %9s\n' GPU "$(awk '/^GPU Utilisation/ {print $3}' $dbg/pvr/status)" "$(mhz $df/1800000.gpu/cur_freq)"
            printf '%-9s %8s %9s\n' NPU "$(awk 'NR == 1 {print $NF}' $dbg/viplite/core_loading)" "$(mhz $df/3600000.npu/cur_freq)"
            printf '%-9s %6s/s %9s\n' VE-DEC "$((d - dec))" "$(mhz $clk/ve-dec/clk_rate)"
            printf '%-9s %6s/s %9s\n' VE-ENC "$((e - enc))" "$(mhz $clk/ve-enc0/clk_rate)"
            printf '%-9s %8s %9s\n' DRAM - "$(mhz $clk/dram0/clk_rate)"
            for z in /sys/class/thermal/thermal_zone*; do
              printf '%-9s %7sC\n' "$(sed 's/_thermal_zone//; s/_zone//' "$z/type")" "$(( $(cat "$z/temp") / 1000 ))"
            done
          )
          dec=$d; enc=$e
          printf '\033[H\033[2J%s\n' "$out"
        done
      '';
    })
  ];
  environment.pathsToLink = [ "/share/vpm_run" ];
}
