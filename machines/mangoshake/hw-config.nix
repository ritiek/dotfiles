{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # TODO: I should also look into `bootCounter` option sometime for
  # systemd-boot systems:
  # https://github.com/NixOS/nixpkgs/pull/330017

  # FIXME: Doesn't work at the moment for some reason. Needs debugging.
  # boot.initrd.systemd = {
  #   timers.timeout-reset = {
  #     description = "Reset if boot takes too long";
  #     wantedBy = [ "initrd.target" ];
  #     timerConfig = {
  #       OnActiveSec = 60 * 10; # 10 minutes
  #     };
  #   };
  #
  #   services.timeout-reset = {
  #     description = "Reset if boot takes too long";
  #     serviceConfig.ExecStart = ''
  #       echo b > /proc/sysrq-trigger
  #     '';
  #   };
  # };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      autoResize = true;
      options = [ "noatime" ];
    };
  };

  # disko.devices.disk.${config.networking.hostName} = {
  #   device = "/dev/disk/by-label/NIXOS_SD";
  #   content = {
  #     type = "gpt";
  #     partitions = {
  #       # boot = {
  #       #   size = "2M";
  #       #   type = "EF02";
  #       # };
  #       esp = {
  #         size = "200M";
  #         type = "EF00";
  #         content = {
  #           type = "filesystem";
  #           format = "vfat";
  #           mountpoint = "/boot";
  #         };
  #       };
  #       nix = {
  #         end = "-3G";
  #         content = {
  #           type = "filesystem";
  #           format = "btrfs";
  #           mountpoint = "/nix";
  #           mountOptions = [
  #             "noatime"
  #             "compress-force=zstd:3"
  #           ];
  #           extraArgs = [ "-Lnix" ];
  #         };
  #       };
  #       plain-swap = {
  #         size = "100%";
  #         content = {
  #           type = "swap";
  #           discardPolicy = "both";
  #           resumeDevice = true;
  #         };
  #       };
  #     };
  #   };
  # };
  #
  # disko.devices.nodev = {
  #   "/" = {
  #     fsType = "tmpfs";
  #     mountOptions = [
  #       "size=2G"
  #       "mode=755"
  #     ];
  #   };
  # };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
