{ config, pkgs, lib, ... }:

let
  homelab-media-mount-monitor-loop = pkgs.writeShellScriptBin "homelab-media-mount-monitor-loop" ''
    while true; do
      if ! ${pkgs.util-linux}/bin/mountpoint -q /media/HOMELAB_MEDIA; then
        ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=1
        ${pkgs.coreutils}/bin/sleep 2
        ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=0
        ${pkgs.coreutils}/bin/sleep 2
      else
        ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=0
        ${pkgs.coreutils}/bin/sleep 2
      fi
    done
  '';
in
{
  systemd.user.services.homelab-media-mount-monitor = {
    Unit = {
      Description = "Mount monitor for HOMELAB_MEDIA on Blue LED";
      After = [ "local-fs.target" ];
    };
    Service = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "10s";
      ExecStart = "${homelab-media-mount-monitor-loop}/bin/homelab-media-mount-monitor-loop";
      ExecStopPost = "${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=0";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
