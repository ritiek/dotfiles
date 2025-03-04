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

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."paperless-ngx-push.env".path}
    source ~/.config/sops-nix/secrets/paperless-ngx-push.env

    USERNAME=$(${pkgs.curl}/bin/curl -s -H "Authorization: Token $PAPERLESS_NGX_API_KEY" "$PAPERLESS_NGX_INSTANCE_URL/api/users/" | ${pkgs.jq}/bin/jq -r '.results[].username')

    if [ $? -ne 0 ]; then
      echo "/api/users/ returned status code $?, exiting."
      exit $?
    fi

    if [[ "$USERNAME" != "${config.home.username}" ]]; then
      echo "/api/users/ endpoint returned invalid username, exiting."
      exit 1
    fi

    LAST_RUN_TIMESTAMP=$(${pkgs.coreutils}/bin/cat "$TIMESTAMP_FILE")

    # Process each path pattern in the sync paths file
    while IFS= read -r PATH_PATTERN; do
      # Split pattern into directory and filename components
      dir_part="$(dirname "$PATH_PATTERN")"
      file_pattern="$(basename "$PATH_PATTERN")"

      # Skip if directory doesn't exist
      if [[ ! -d "$dir_part" ]]; then
        echo "Directory does not exist: $dir_part"
        continue
      fi

      # Expand files safely
      shopt -s nullglob
      files=("$dir_part"/$file_pattern)  # Intentional unquoted $file_pattern for glob expansion
      shopt -u nullglob

      for FILE in "''${files[@]}"; do
        if [[ -f "$FILE" ]]; then
          FILE_CREATION_DATE=$(${pkgs.coreutils}/bin/stat -c %W "$FILE")

          if [[ "$FILE_CREATION_DATE" -gt "$LAST_RUN_TIMESTAMP" ]]; then
            # Requires ./scripts/home/paperless-ngx-push.nix
            /etc/profiles/per-user/${config.home.username}/bin/paperless-ngx-push "$FILE"

            if [ $? -ne 0 ]; then
              echo "paperless-ngx-push returned status code $?, exiting."
              exit $?
            fi
            echo
          fi
        fi
      done
    done < "$SYNC_PATHS_FILE"

    echo "$CURRENT_TIMESTAMP" > "$TIMESTAMP_FILE"
    echo "Sync complete."
  '');

  ping-uptime-kuma = (pkgs.writeShellScriptBin "ping-uptime-kuma@paperless-ngx-sync" ''
    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    source ~/.config/sops-nix/secrets/uptime-kuma.env

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/8sKmxnwk3t?status=$STATUS&msg=$SERVICE_RESULT&ping="

    if [ $? -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma succeeded."
    else
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma failed."
      exit $?
    fi
  '');
in
{
  imports = [
    ./../../../../scripts/home/paperless-ngx-push.nix
  ];
  sops.secrets."uptime-kuma.env" = {};

  home.packages = with pkgs; [
    paperless-ngx-sync
    curl
    jq
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
      ExecStopPost = "${ping-uptime-kuma}/bin/ping-uptime-kuma@paperless-ngx-sync";
    };
  };

  systemd.user.timers.paperless-ngx-sync = {
    Unit = {
      Description = "Run sync paperless-ngx service periodically.";
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
      Unit = "paperless-ngx-sync.service";
    };
    # Install = {
    #   WantedBy = [ "timers.target" ];
    # };
  };
}
