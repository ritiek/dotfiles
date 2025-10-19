{ config, pkgs, lib, servicePaths, everythingElsePath, homelabMediaPath, ... }:

let
  lsyncdConfig = pkgs.writeText "lsyncd.conf" ''
    settings {
      nodaemon = true,
    }

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: paths: ''
      sync {
        default.rsync,
        source = "${paths.configSource}",
        target = "${paths.configBackup}",
        rsync = {
          archive = true,
          compress = false,
        }
      }
    '') servicePaths)}
  '';
in
{
  # Create backup directories
  systemd.tmpfiles.rules = lib.mapAttrsToList (name: paths:
    "d ${paths.configBackup} 0755 root root -"
  ) servicePaths;

  systemd.services.lsyncd = {
    description = "Lsyncd - Live Syncing Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [
      "media-EVERYTHING_ELSE.mount"
      "media-HOMELAB_MEDIA.mount"
      "network.target"
    ];
    requires = [
      "media-EVERYTHING_ELSE.mount"
      "media-HOMELAB_MEDIA.mount"
    ];
    unitConfig.RequiresMountsFor = [
      everythingElsePath
      homelabMediaPath
    ];
    path = [ pkgs.rsync ];
    serviceConfig = {
      ExecStart = "${pkgs.lsyncd}/bin/lsyncd ${lsyncdConfig}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
