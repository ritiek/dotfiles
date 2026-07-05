# Prebuilt Allwinner boot0 (SPL / DRAM-init) and boot_package (packed U-Boot)
# blobs for the Radxa Cubie A7S (Allwinner A733 / sun60iw2).
#
# We do NOT build U-Boot from source. The Radxa U-Boot for this SoC is a
# heavily customised Android/AIOT fork built with Allwinner's closed
# "pack-uboot" tooling (x86-only ELF binaries - see
# armbian/build's sun60iw2.conf for the only known workaround, wrapping the
# tools with qemu-x86_64-static). Every known working project for this board
# (OctaneOS/Batocera, NickAlilovic's Armbian fork) instead just `dd`s
# prebuilt vendor blobs onto the SD card at fixed raw byte offsets, which is
# exactly what we do here.
#
# Provenance: these two files originate from Radxa's own official release
#   https://github.com/radxa-build/radxa-a733/releases/tag/rsdk-r2
#   (radxa-a733_bullseye_cli_r2.output_512.img.xz), extracted at:
#     boot0_sdcard.fex  @ byte offset 0x20000  (128 KiB), size 245760 bytes
#     boot_package.fex  @ byte offset 0xC00000 (12 MiB),  size 1441792 bytes
#
# Rather than re-downloading that ~595MB image ourselves just to `dd` out
# 1.5MB, we fetch GameOctane/OctaneOS's already-extracted copies of the same
# two files (pinned to a fixed commit). We independently verified byte-for-
# byte that these are genuine, unmodified Allwinner blobs (eGON.BT03 magic
# at boot0 offset 4, "sunxi-package" magic at boot_package offset 0), and
# have validated them on real hardware: a full cold SD-card boot produced a
# correct DRAM training log (LPDDR5, 6144MB) and a working U-Boot prompt.
#
# License note: these are vendor-provided binary blobs. OctaneOS's own
# GPLv3 LICENSE file does not (and cannot) grant redistribution rights over
# them - treat as unfree/redistribution-status-unclear, same as any other
# vendor SoC bring-up blob.
{ lib, stdenvNoCC, fetchurl }:

let
  octaneosCommit = "cd24480c308db02d0c219453edd7f7df81ff9766";
  octaneosRaw = path: "https://raw.githubusercontent.com/GameOctane/OctaneOS/${octaneosCommit}/${path}";

  boot0 = fetchurl {
    url = octaneosRaw "board/batocera/allwinner/a733/cubie-a7s/boot/boot0_sdcard.fex";
    sha256 = "1ljdyn19zhdfar441f8x1rg76ja4si1izbpk61drpc8h1c9wm1kd";
  };

  bootPackage = fetchurl {
    url = octaneosRaw "board/batocera/allwinner/a733/cubie-a7s/boot/boot_package.fex";
    sha256 = "1qz4m11dvqjlcby26ybax3dv2gmfn4622b2dbswb0fb41r9jv91w";
  };
in
stdenvNoCC.mkDerivation {
  pname = "uboot-cubie-a7s";
  version = "rsdk-r2";

  dontUnpack = true;

  # Raw byte offsets these files must be `dd`'d to on the target SD card -
  # exposed as passthru so flake.nix's sdImage.postBuildCommands can stay
  # in sync with this derivation without hardcoding the numbers twice.
  passthru = {
    boot0Offset = 131072; # 0x20000 bytes = 128 KiB
    bootPackageOffset = 12582912; # 0xC00000 bytes = 12 MiB
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp ${boot0} $out/boot0_sdcard.fex
    cp ${bootPackage} $out/boot_package.fex
    runHook postInstall
  '';

  meta = with lib; {
    description = "Prebuilt Allwinner boot0 + boot_package blobs for Radxa Cubie A7S (A733/sun60iw2) SD-card boot";
    homepage = "https://github.com/radxa-build/radxa-a733/releases/tag/rsdk-r2";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryFirmware ];
    platforms = [ "aarch64-linux" ];
  };
}
