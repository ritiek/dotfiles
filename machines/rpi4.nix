{ config, pkgs, lib, ... }:
let
  nixos-hardware = builtins.fetchTarball "https://github.com/NixOS/nixos-hardware/archive/master.tar.gz";
in
{
  imports = [
    (import "${nixos-hardware}/raspberry-pi/4")
  ];

  services.openssh.enable = true;
  hardware = {
    # pulseaudio.enable = true;
    # raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    # raspberry-pi."4".fkms-3d.enable = true;
    # raspberry-pi."4".audio.enable = true;
  };
  console.enable = false;
  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];
  # system.stateVersion = "23.11";
}
