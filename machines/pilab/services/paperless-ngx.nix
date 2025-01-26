{ config, pkgs, lib, inputs, ... }:
let
  paperless-ngx-sync = (pkgs.writeShellScriptBin "paperless-ngx-sync" ''
    SYNC_PATHS_FILE="sync-paths.txt"
    TIMESTAMP_FILE=".last_sync_timestamp"

    CURRENT_TIMESTAMP=$(date +%s)

    # If the timestamp file doesn't exist, create it with a dummy timestamp
    if [[ ! -f "$TIMESTAMP_FILE" ]]; then
        echo "0" > "$TIMESTAMP_FILE"
    fi

    LAST_RUN_TIMESTAMP=$(cat "$TIMESTAMP_FILE")

    # Process each path pattern in the sync paths file
    while IFS= read -r PATH_PATTERN; do
        for FILE in $PATH_PATTERN; do
            if [[ -f "$FILE" ]]; then
                FILE_CREATION_DATE=$(stat -c %W "$FILE")
                
                if [[ "$FILE_CREATION_DATE" -gt "$LAST_RUN_TIMESTAMP" ]]; then
                    ${pkgs.paperless-ngx-push}/bin/paperless-ngx-push "$FILE"
                fi
            fi
        done
    done < "$SYNC_PATHS_FILE"

    echo "$CURRENT_TIMESTAMP" > "$TIMESTAMP_FILE"
    echo "Sync complete."
  '');
in
{
  environment.systemPackages = with pkgs; [
    paperless-ngx-sync
  ];

  # systemd.services.spotdl-sync = {
  #   path = [ pkgs.spotdl ];
  #   unitConfig = {
  #     Description = "Sync Spotify playlists locally.";
  #     RequiresMountsFor = [
  #       "/media/HOMELAB_MEDIA/services/spotdl"
  #     ];
  #   };
  #   serviceConfig = {
  #     Type = "oneshot";
  #     WorkingDirectory = "/media/HOMELAB_MEDIA/services/spotdl";
  #     ExecStart = "${paperless-ngx-push/bin/paperless-ngx-push";
  #     # ExecStop = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";
  #     # ExecReload = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";
  #
  #     # Restart = lib.mkOverride 500 "always";
  #     # RestartMaxDelaySec = lib.mkOverride 500 "1m";
  #     # RestartSec = lib.mkOverride 500 "100ms";
  #     # RestartSteps = lib.mkOverride 500 9;
  #   };
  #   after = [
  #     "network-online.target"
  #   ];
  #   requires = [
  #     "network-online.target"
  #   ];
  #   # wantedBy = [ "multi-user.target" ];
  # };
  #
  # systemd.timers.spotdl-sync = {
  #   unitConfig = {
  #     Description = "Run sync Spotify playlists service periodically.";
  #   };
  #   timerConfig = {
  #     OnBootSec = "1m";
  #     OnUnitActiveSec = "6h";
  #     Unit = "spotdl-sync.service";
  #   };
  #   # wantedBy = [ "timers.target" ];
  # };
}
