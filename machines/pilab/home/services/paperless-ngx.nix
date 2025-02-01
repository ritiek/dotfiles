{ config, pkgs, lib, inputs, ... }:
let
  paperless-ngx-sync = (pkgs.writeShellScriptBin "paperless-ngx-sync" ''
    SYNC_PATHS_FILE="sync_paths.txt"
    TIMESTAMP_FILE=".last_sync_timestamp"

    # If the sync paths file doesn't exist, exit
    if [[ ! -f "$SYNC_PATHS_FILE" ]]; then
      echo "$SYNC_PATHS_FILE file not found in current working directory, exiting."
      exit 1
    fi

    CURRENT_TIMESTAMP=$(${pkgs.coreutils}/bin/date +%s)

    # If the timestamp file doesn't exist, create it with a dummy timestamp
    if [[ ! -f "$TIMESTAMP_FILE" ]]; then
      echo "0" > "$TIMESTAMP_FILE"
    fi

    LAST_RUN_TIMESTAMP=$(${pkgs.coreutils}/bin/cat "$TIMESTAMP_FILE")

    # Process each path pattern in the sync paths file
    while IFS= read -r PATH_PATTERN; do
      for FILE in $PATH_PATTERN; do
        if [[ -f "$FILE" ]]; then
          FILE_CREATION_DATE=$(${pkgs.coreutils}/bin/stat -c %W "$FILE")

            if [[ "$FILE_CREATION_DATE" -gt "$LAST_RUN_TIMESTAMP" ]]; then
              # Requires ./scripts/home/paperless-ngx-push.nix
              /etc/profiles/per-user/${config.home.username}/bin/paperless-ngx-push "$FILE"
              echo
            fi
        fi
      done
    done < "$SYNC_PATHS_FILE"

    echo "$CURRENT_TIMESTAMP" > "$TIMESTAMP_FILE"
    echo "Sync complete."
  '');
in
{
  home.packages = with pkgs; [
    paperless-ngx-sync
  ];

  systemd.user.services.paperless-ngx-sync = {
    Unit = {
      Description = "Sync Documents to paperless-ngx.";
      RequiresMountsFor = [
        "/media/HOMELAB_MEDIA/services/paperless"
      ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "/media/HOMELAB_MEDIA/services/paperless";
      ExecStart = "${paperless-ngx-sync}/bin/paperless-ngx-sync";
    };
  };

  systemd.user.timers.paperless-ngx-sync = {
    Unit = {
      Description = "Run sync paperless-ngx service periodically.";
    };
    Timer = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1h";
      Unit = "paperless-ngx-sync.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
