{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  # Hardware support for the Radxa Cubie A5E (aic8800 wifi/bt driver, board
  # workarounds, disk/boot layout) is vendored locally in this directory
  # rather than pulled in as a flake input.
  # Source: https://github.com/patryk4815/nixos-cubie-a5e
  imports = [
    ./aic8800-sdio.nix
    ./cubie-a5e.nix
    ./disko.nix
  ];

  hardware.cubie-a5e.enable = true;

  # Pinned to match the nixos-cubie-a5e repo's own kernel version (the aic8800
  # SDIO wifi/bt driver requires kernel >= 7.0 - see ./aic8800-sdio.nix).
  boot.kernelPackages = pkgs.linuxPackages_7_0;

  # A523/A527 thermal sensor support (THS0/THS1) is provided via
  # boot.kernelPatches in ./cubie-a5e.nix (gated on hardware.cubie-a5e.enable
  # above), not here - do not duplicate that list in this file, since
  # boot.kernelPatches is list-typed and duplicate entries get concatenated,
  # causing patches to be applied twice (the second application then fails
  # with "Reversed (or previously applied) patch detected").

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelModules = [ "g_ether" ];

  # USB gadget ethernet - allows SSH over USB-C on first boot
  # Connect to 10.0.0.4 from host (configure host side as 10.0.0.1/24)
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.4";
    prefixLength = 24;
  }];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
