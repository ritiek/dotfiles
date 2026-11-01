# `nix build /etc/nixos#nixstation-sd`, then write it to the USB SSD.
# Partition 1 (FAT, PS4BOOT) holds what the ps4-linux-loader payload looks
# for; partition 2 is the btrfs root that initramfs-ps4 mounts by label.
{ config, lib, pkgs, modulesPath, ... }:

let
  loader = pkgs.fetchzip {
    url = "https://github.com/ps4-linux/ps4-linux-loader/releases/download/v25.2/PS4-Linux-Loader-v25.2.zip";
    hash = "sha256-6s96u0HXSVdUVt3jB1unKBmIe0JSUGClJW7wq10vqtE=";
    stripRoot = false;
  };
  # Strawberry 7.0.8 Baikal build, only published as a mirrored bzImage.
  kernel = pkgs.fetchurl {
    url = "https://gatto.fae5.de/archive/kernels/strawberry/baikal/7.0.8/bzImage";
    hash = "sha256-Rsg192LnsLVADqdiuNqhvOxjiht2nH7AkFE3vFZbG6g=";
  };
  # shortcut: initramfs-ps4 only publishes rolling tags, so this hash breaks
  # when `latest` moves; update the hash (or mirror the file) when it does.
  initramfs = pkgs.fetchurl {
    url = "https://git.gay/GayCorp/initramfs-ps4/releases/download/latest/initramfs.cpio.gz";
    hash = "sha256-iG87lLa5XJBZo0MSw3qN8iVlpiWziDbKKeg/Rof/Tdw=";
  };
  # Replaces the loader's built-in cmdline; first line only.
  bootargs = pkgs.writeText "bootargs.txt"
    "panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0 drm.debug=0 console=ttyS0,115200n8 console=tty0 video=HDMI-A-1:1920x1080@60";
in
{
  imports = [ (modulesPath + "/installer/sd-card/sd-image.nix") ];

  # sd-image turns this on; with no NixOS kernel/initrd it would only add
  # linux-firmware, and the Wi-Fi firmware is built into the PS4 kernel.
  hardware.enableAllHardware = lib.mkForce false;

  sdImage = {
    firmwarePartitionName = "PS4BOOT";
    firmwareSize = 512;
    rootVolumeLabel = "psxitarch";
    rootFilesystemCreator = ../../modules/radxa-zero3/make-btrfs-fs.nix;
    populateFirmwareCommands = ''
      cp ${kernel} firmware/bzImage
      cp ${initramfs} firmware/initramfs.cpio.gz
      cp ${bootargs} firmware/bootargs.txt
      mkdir firmware/payloads
      cp ${loader}/bin/linux-1024mb.bin ${loader}/elf/linux-1024mb.elf firmware/payloads/
    '';
    # initramfs-ps4 checks `[ -e /newroot/sbin/init ]` before switch_root, so
    # this has to be a real file, and /bin/sh doesn't exist until activation.
    # The first switch replaces it via boot.loader.initScript.
    populateRootCommands = ''
      mkdir -p files/sbin
      printf '#!%s\nexec %s/init\n' ${pkgs.runtimeShell} ${config.system.build.toplevel} > files/sbin/init
      chmod 755 files/sbin/init
    '';
  };

  fileSystems."/".fsType = lib.mkForce "btrfs";

  # Upstream's first-boot grow runs resize2fs, which is ext4-only.
  systemd.services.expand-root-partition.script = lib.mkForce ''
    rootPart=$(${lib.getExe' pkgs.util-linux "findmnt"} -n -o SOURCE /)
    bootDevice=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo PKNAME $rootPart)
    partNum=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo MAJ:MIN $rootPart | ${lib.getExe pkgs.gawk} -F: '{print $2}')
    echo ",+," | ${lib.getExe' pkgs.util-linux "sfdisk"} -N$partNum --no-reread $bootDevice
    ${lib.getExe' pkgs.parted "partprobe"}
    ${lib.getExe pkgs.btrfs-progs} filesystem resize max /
  '';
}
