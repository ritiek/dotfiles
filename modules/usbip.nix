{ pkgs, ... }:
{
  boot.kernelModules = [ "vhci-hcd" ];
  environment.systemPackages = with pkgs; [
    linuxPackages.usbip
  ];
}
