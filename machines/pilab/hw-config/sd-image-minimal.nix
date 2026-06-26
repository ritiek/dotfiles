{ config, lib, pkgs, nixos-raspberrypi, ... }:

# Minimal SSH-only bootstrap SD image for `pilab`.
#
# Purpose: flash this to an SD card, boot the Pi from it, then run
# nixos-anywhere against a separate NVMe/SSD to install the full `pilab`
# config (which uses the disko btrfs layout in hw-config/disko.nix).
#
# Throwaway image: plain ext4 root with autoResize (uses the stock
# resize2fs-based expander). Keep it lean.

{
  imports = with nixos-raspberrypi.nixosModules; [ sd-image ];

  # Stock ext4 root expansion on first boot.
  sdImage.expandOnBoot = true;

  # Enable SSH so we can reach the box to run nixos-anywhere.
  services.openssh = {
    enable = true;
    settings = {
      # Base machines/pilab sets this to "no"; the bootstrap image needs root
      # SSH so nixos-anywhere can deploy the real config.
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = config.users.users.ritiek.openssh.authorizedKeys.keys or [ ];

  # Pull in tooling typically needed during a nixos-anywhere install.
  environment.systemPackages = with pkgs; [
    btrfs-progs
    parted
    git
  ];

  # networking.useDHCP is already set in the shared hw-config.nix base.

  system.nixos.tags = [ "pilab-minimal-bootstrap" ];
}
