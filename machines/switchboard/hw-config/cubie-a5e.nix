
# Vendored from https://github.com/patryk4815/nixos-cubie-a5e
# (modules/cubie-a5e.nix)
{ pkgs, lib, config, ... }:
let
  cfg = config.hardware.cubie-a5e;
in
{
  options.hardware.cubie-a5e = {
    enable = lib.mkEnableOption "Radxa Cubie A5E board support";

    watchdog-reboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable watchdog-based reboot workaround for WIP TF-A (no PSCI SYSTEM_RESET)";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.aic8800.enable = true;

    # Hardware watchdog for reliable reboot/shutdown detection
    systemd.settings.Manager = {
      RuntimeWatchdogSec = "15s";
      RebootWatchdogSec = "15s";
    };

    # Workaround: WIP TF-A doesn't support PSCI SYSTEM_RESET
    # Crash kernel on shutdown so hardware watchdog triggers reboot
    systemd.services.watchdog-reboot-helper = lib.mkIf cfg.watchdog-reboot {
      description = "Crash kernel for reboot";
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown.target" ];
      conflicts = [ "shutdown.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        ExecStop = "${pkgs.bash}/bin/bash -c 'echo c > /proc/sysrq-trigger'";
      };
    };
  };
}
