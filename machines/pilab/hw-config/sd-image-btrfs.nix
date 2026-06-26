{ config, lib, pkgs, nixos-raspberrypi, ... }:

# Full SD-card image for `pilab` with a btrfs root.
#
# NOTE: the nixpkgs sd-image builder uses make-btrfs-fs.nix, which produces a
# FLAT btrfs filesystem (no subvolumes). The @/@home/@nix/... subvolume layout
# is a disko-only feature (see hw-config/disko.nix). This image is a single
# btrfs root labelled NIXOS_SD.
#
# Auto-grow on first boot is handled manually because the stock
# expand-root-partition service uses resize2fs (ext4-only).

{
  imports = with nixos-raspberrypi.nixosModules; [ sd-image ];

  # Build the root filesystem as btrfs instead of ext4.
  sdImage.rootFilesystemCreator = "${pkgs.path}/nixos/lib/make-btrfs-fs.nix";

  # The sd-image module sets fileSystems."/".fsType = "ext4" at normal priority;
  # override it to btrfs.
  fileSystems."/".fsType = lib.mkForce "btrfs";
  fileSystems."/".options = lib.mkForce [ "noatime" "compress-force=zstd:3" ];

  # resize2fs cannot grow btrfs; disable the stock expander and grow manually.
  sdImage.expandOnBoot = false;

  systemd.services.expand-root-btrfs = {
    description = "Grow the root partition and btrfs filesystem to fill the SD card";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "sysinit.target" ];
    before = [ "sysinit.target" "shutdown.target" ];
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      rootPart=$(${lib.getExe' pkgs.util-linux "findmnt"} -n -o SOURCE /)
      bootDevice=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo PKNAME $rootPart)
      partNum=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo MAJ:MIN $rootPart | ${lib.getExe pkgs.gawk} -F: '{print $2}')

      echo ",+," | ${lib.getExe' pkgs.util-linux "sfdisk"} -N$partNum --no-reread $bootDevice
      ${lib.getExe' pkgs.parted "partprobe"} || true
      ${lib.getExe' pkgs.btrfs-progs "btrfs"} filesystem resize max /
    '';
  };
}
