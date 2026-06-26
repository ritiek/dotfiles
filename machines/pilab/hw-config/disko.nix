{ config, lib, ... }:

# Disko layout for the `pilab` install target (deployed via nixos-anywhere).
#
# Btrfs root with a subvolume layout, plus a FAT firmware partition for the
# Raspberry Pi bootloader. The firmware partition is only FORMATTED by disko;
# its contents are POPULATED by the nixos-raspberrypi bootloader activation
# scripts on every generation switch (so nixos-anywhere needs no interactive
# step). Do NOT attempt to copy firmware files here.
#
# IMPORTANT: you cannot run disko/nixos-anywhere against the disk you are
# currently booted from. Boot the Pi from the minimal SD image
# (`pilab-minimal-sd`) and deploy this layout onto a separate NVMe/SSD.

let
  # Root filesystem mount options, matching HOMELAB_MEDIA.
  #
  # NOTE: btrfs applies `compress`/`compress-force`, `nodatacow` and `nodatasum`
  # filesystem-wide, governed by the FIRST mounted subvolume (`@` -> `/`). The
  # per-subvolume copies below are therefore only meaningful for `@`; for the
  # other subvolumes only `noatime`/`ssd`/`space_cache` apply individually. They
  # are listed consistently for clarity.
  btrfsMountOptions = [
    "defaults"
    "noatime"
    "nodiscard"
    "noautodefrag"
    "ssd"
    "space_cache=v2"
    "compress-force=zstd:3"
  ];
in
{
  # Pi 5: use the new generational "kernel" bootloader (recommended for new
  # installs) rather than the legacy kernelboot.
  boot.loader.raspberry-pi.bootloader = "kernel";

  # Mount /var/log early so no logs are lost during boot.
  fileSystems."/var/log".neededForBoot = true;

  # Make udisks ignore the firmware partition (GPT "Required Partition" flag
  # 0x1) so it isn't auto-mounted or surfaced in the UI.
  services.udev.extraRules = ''
    ENV{ID_PART_ENTRY_SCHEME}=="gpt", ENV{ID_PART_ENTRY_FLAGS}=="0x1", ENV{UDISKS_IGNORE}="1"
  '';

  disko.devices = {
    disk.main = {
      # Override at deploy time, e.g.
      #   --arg device '"/dev/nvme0n1"'  or set in a host-specific module.
      device = lib.mkDefault "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Raspberry Pi firmware partition (FAT). Formatted here, populated by
          # bootloader activation scripts. Sized generously: the "kernel"
          # bootloader keeps a full kernel + initrd + DTBs per generation.
          FIRMWARE = {
            priority = 1;
            type = "0700"; # Microsoft basic data
            attributes = [ 0 ]; # GPT "Required Partition" -> udisks ignores it
            size = "1024M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/firmware";
              mountOptions = [
                "noatime"
                "noauto"
                "x-systemd.automount"
                "x-systemd.idle-timeout=1min"
              ];
            };
          };

          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "NIXOS_SD" ];
              subvolumes = {
                "/@" = {
                  mountpoint = "/";
                  mountOptions = btrfsMountOptions;
                };
                "/@home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsMountOptions;
                };
                "/@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsMountOptions;
                };
                "/@var-lib" = {
                  mountpoint = "/var/lib";
                  mountOptions = btrfsMountOptions;
                };
                # Keep the ~67G docker overlay2 store out of root snapshots.
                "/@docker" = {
                  mountpoint = "/var/lib/docker";
                  mountOptions = btrfsMountOptions;
                };
                "/@log" = {
                  mountpoint = "/var/log";
                  mountOptions = btrfsMountOptions;
                };
              };
            };
          };
        };
      };
    };
  };
}
