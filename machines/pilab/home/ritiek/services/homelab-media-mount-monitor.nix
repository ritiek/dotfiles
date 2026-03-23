{ config, pkgs, lib, ... }:

let
  blink-blue-led = pkgs.writeShellScriptBin "blink-blue-led" ''
    while true; do
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=1
      ${pkgs.coreutils}/bin/sleep 2
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=0
      ${pkgs.coreutils}/bin/sleep 2
    done
  '';
in
{
  systemd.user.services.homelab-media-mount-monitor = {
    Unit = {
      Description = "Blue LED blink indicator for HOMELAB_MEDIA not mounted";
      After = [ "local-fs.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${blink-blue-led}/bin/blink-blue-led";
      ExecStopPost = "${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=0";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
