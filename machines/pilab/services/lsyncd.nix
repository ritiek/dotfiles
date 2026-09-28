{ config, pkgs, lib, servicePaths, homelabMediaPath, ... }:

let
  runtimeConfig = "/run/lsyncd/lsyncd.conf";

  syncFragment = name: paths: pkgs.writeText "lsyncd-sync-${name}.conf" ''
    sync {
      default.rsync,
      source = "${paths.configSource}",
      target = "${paths.configBackup}",
      ${lib.optionalString (paths ? exclude) ''
        exclude = { ${lib.concatMapStringsSep ", " (p: "\"${p}\"") paths.exclude} },
      ''}
      rsync = {
        archive = true,
        compress = false,
      }
    }
  '';

  # lsyncd aborts with a non-zero exit if *any* single source directory is
  # missing, which would take down syncing for every other service. Some
  # sources live on removable media that may be absent (and whose mountpoint
  # is chattr +i so it cannot be pre-created). So build the config at start
  # time and emit sync blocks only for sources that currently exist. If the
  # missing media comes back, a restart picks it up automatically.
  generateConfig = pkgs.writeShellScript "lsyncd-generate-config" ''
    set -eu

    cat > ${runtimeConfig} <<'EOF'
    settings {
      nodaemon = true,
    }
    EOF

    synced=0
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: paths: ''
      if [ -d '${paths.configSource}' ]; then
        cat ${syncFragment name paths} >> ${runtimeConfig}
        synced=$((synced + 1))
      else
        echo "lsyncd: SKIPPING '${name}': source '${paths.configSource}' does not exist" >&2
      fi
    '') servicePaths)}

    if [ "$synced" -eq 0 ]; then
      echo "lsyncd: no existing sources to sync, refusing to start" >&2
      exit 1
    fi
    echo "lsyncd: configured $synced sync(s)"
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
      "media-HOMELAB_MEDIA.mount"
      # "network.target"
    ];
    requires = [
      "media-HOMELAB_MEDIA.mount"
    ];
    unitConfig.RequiresMountsFor = [
      homelabMediaPath
    ];
    path = [ pkgs.rsync ];
    serviceConfig = {
      RuntimeDirectory = "lsyncd";
      ExecStartPre = "${generateConfig}";
      ExecStart = "${pkgs.lsyncd}/bin/lsyncd ${runtimeConfig}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
