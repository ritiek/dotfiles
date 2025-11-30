{ lib, config, pkgs, homelabMediaPath, enableLEDs, ...}:

let
  ping-uptime-kuma-pilab = (pkgs.writeShellScriptBin "ping-uptime-kuma@restic-backups-homelab@pilab" ''
    # TODO: I should make a common shell script for uptime kuma pings instead of
    # re-defining this shell script everywhere.

    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    #
    # TODO: Make this work work without hardcoding my username.
    source "${config.home.homeDirectory}/.config/sops-nix/secrets/uptime-kuma.env"

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/BmioyeNZTb?status=$STATUS&msg=$SERVICE_RESULT&ping="
    curl_exit_code=$?

    if [ $curl_exit_code -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma succeeded."
    else
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma failed."
      exit $curl_exit_code
    fi
  '');

  ping-uptime-kuma-keyberry = (pkgs.writeShellScriptBin "ping-uptime-kuma@restic-backups-homelab@keyberry" ''
    # TODO: I should make a common shell script for uptime kuma pings instead of
    # re-defining this shell script everywhere.

    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    #
    # TODO: Make this work work without hardcoding my username.
    source "${config.home.homeDirectory}/.config/sops-nix/secrets/uptime-kuma.env"

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/lNLKLfskQD?status=$STATUS&msg=$SERVICE_RESULT&ping="

    curl_exit_code=$?

    if [ $curl_exit_code -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma succeeded."
    else
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma failed."
      exit $curl_exit_code
    fi
  '');
in
{
  sops.secrets."restic.homelab.password" = {};
  # sops.secrets."restic.homelab.password".owner = "restic";

  # Copy pasto from here to keep restic user's UID & GID consistent with
  # services.restic.server:
  # https://github.com/NixOS/nixpkgs/blob/01115de/nixos/modules/services/backup/restic-rest-server.nix#L135-L142
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix
  #
  # Since backups through services.restic.server are created through the
  # restic user. Setting the same UID & GID allows to swap the same backup
  # media between this (pilab) and other machines (zerostash/keyberry).
  users.users.restic = {
    group = "restic";
    home = "${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA";
    createHome = true;
    uid = config.ids.uids.restic;
  };

  users.groups.restic.gid = config.ids.uids.restic;

  fileSystems.restic-backup = {
    mountPoint = "/media/${config.fileSystems.restic-backup.label}";
    device = "/dev/disk/by-label/${config.fileSystems.restic-backup.label}";
    fsType = "ext4";
    label = "RESTIC_BACKUP";
    autoResize = true;
    options = [
      "noatime"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=5s"
    ];
  };

  # https://nixos.wiki/wiki/Restic
  # security.wrappers.restic = {
  #   source = "${pkgs.restic}/bin/restic";
  #   owner = "restic";
  #   group = "users";
  #   permissions = "u=rwx,g=,o=";
  #   capabilities = "cap_dac_read_search=+ep";
  # };

  services.restic.backups."homelab@pilab" = {
    initialize = true;
    # repositoryFile = config.sops.secrets."pilab.repository".path;
    repository = "${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA";
    passwordFile = config.sops.secrets."restic.homelab.password".path;
    # user = "restic";
    paths = [
      homelabMediaPath
    ];
    # exclude = [
    #   "*.db-shm"
    #   "*.db-wal"
    #   "LOCK"
    #   "media.lock"
    #   "migration_lock"
    # ];
    extraBackupArgs = [
      "--compression=max"
    ];
    pruneOpts = [
      "--keep-hourly 18"
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 75"
      "--keep-tag forever"
    ];
    # Don't need to assert whether the repository path is correctly mounted as systemd
    # automount will not let any process write to the repository if it's not mounted.
    #
    # backupPrepareCommand = ''
    #   if !${pkgs.util-linux}/bin/mountpoint -q "${config.sops.secrets."pilab.repository".path}"; then
    #     echo "Error: ${config.sops.secrets."pilab.repository".path} is not mounted. Skipping backup."
    #     exit 1 # Exit with a non-zero status to prevent the backup
    #   fi
    #
    #   # Get the device mapped to /path/to/data.
    #   PARTITION=$(${pkgs.coreutils}/bin/df --output=source ${config.sops.secrets."pilab.repository".path} | tail -n 1)
    #
    #   # Check if the partition label matches.
    #   PARTITION_LABEL=$(${pkgs.util-linux}/bin/lsblk -o NAME,LABEL,MOUNTPOINT | grep "$PARTITION" | ${pkgs.gawk}/bin/awk '{print $2}')
    #
    #   if [ "$PARTITION_LABEL" != "${config.fileSystems.restic-backup.label}" ]; then
    #     echo "Error: Partition label is not '${config.fileSystems.restic-backup.label}'. Found label: $PARTITION_LABEL. Skipping backup."
    #     exit 1 # Exit with a non-zero status to prevent the backup
    #   fi
    #
    #   # If mounted and has the correct label, proceed with backup preparation
    #   echo "${config.sops.secrets."pilab.repository".path} is mounted with label '${config.fileSystems.restic-backup.label}'. Proceeding with backup."
    #
    #   # Remove any stale locks.
    #   ${pkgs.restic}/bin/restic unlock || true
    # '';
    backupPrepareCommand = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q ${homelabMediaPath}; then
        echo "Error: '${homelabMediaPath}' is not mounted. Skipping backup."
        exit 1 # Exit with a non-zero status to prevent the backup
      fi

      # Remove any stale locks.
      ${pkgs.restic}/bin/restic unlock || true

      ${lib.optionalString enableLEDs ''
      # Turn on Blue LED to indicate backup is starting
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=1
      ''}

      echo "Backing up '${homelabMediaPath}'."
    '';
    backupCleanupCommand = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q ${homelabMediaPath}; then
        echo "Error: '${homelabMediaPath}' is not mounted. Skipping post backup cleanup."
        exit 1 # Exit with a non-zero status to prevent the post backup cleanup
      fi

      if ! ${pkgs.util-linux}/bin/mountpoint -q "${config.fileSystems.restic-backup.mountPoint}"; then
        echo "Error: '${config.fileSystems.restic-backup.mountPoint}' is not mounted. Skipping post backup cleanup."
        exit 1 # Exit with a non-zero status to prevent the post backup cleanup
      fi

      echo "Assigning ownership to 'restic:restic' on '${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA'."
      chown -R ${builtins.toString config.ids.uids.restic}:${builtins.toString config.ids.uids.restic} \
        "${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA"

      ${lib.optionalString enableLEDs ''
      # Turn off LED now that backup is complete
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 4=0
      ''}

      # ${ping-uptime-kuma-pilab}/bin/ping-uptime-kuma@restic-backups-homelab@pilab
    '';
    timerConfig = {
      # Every 40 minutes
      OnCalendar = "*:0/40";
      Persistent = true;
    };
  };

  systemd.services."restic-backups-homelab@pilab".serviceConfig.ExecStopPost = lib.mkAfter [
    "${ping-uptime-kuma-pilab}/bin/ping-uptime-kuma@restic-backups-homelab@pilab"
  ];

  # systemd.timers."restic-backups-homelab@pilab" = {
  #   enable = true;
  #   description = "Periodically check if pilab's restic backup service is working as expected.";
  #   timerConfig = {
  #     OnBootSec = "5m";
  #     OnUnitActiveSec = "6h";
  #     Unit = "restic-backups-homelab@pilab.service";
  #   };
  # };

  sops.secrets."restic.zerostash.repository" = {};
  # sops.secrets."restic.zerostash.repository".owner = "restic";
  services.restic.backups."homelab@zerostash" = {
    initialize = true;
    repositoryFile = config.sops.secrets."restic.zerostash.repository".path;
    passwordFile = config.sops.secrets."restic.homelab.password".path;
    # user = "restic";
    paths = [
      homelabMediaPath
    ];
    extraBackupArgs = [
      "--compression=max"
    ];
    pruneOpts = [
      "--keep-hourly 18"
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 75"
      "--keep-tag forever"
    ];
    backupPrepareCommand = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q ${homelabMediaPath}; then
        echo "Error: '${homelabMediaPath}' is not mounted. Skipping backup."
        exit 1 # Exit with a non-zero status to prevent the backup
      fi

      # Remove any stale locks.
      ${pkgs.restic}/bin/restic unlock || true

      echo "Backing up '${homelabMediaPath}'."
    '';
    timerConfig = {
      # OnCalendar = "0/6:00"; # Every 6 hours at minute 0
      OnCalendar = "0,6,12,18:00"; # Every day at 00:00, 06:00, 12:00, and 18:00
      Persistent = true;
    };
  };

  sops.secrets."restic.keyberry.repository" = {};
  services.restic.backups."homelab@keyberry" = {
    initialize = true;
    repositoryFile = config.sops.secrets."restic.keyberry.repository".path;
    passwordFile = config.sops.secrets."restic.homelab.password".path;
    paths = [
      homelabMediaPath
    ];
    extraBackupArgs = [
      "--compression=max"
    ];
    pruneOpts = [
      "--keep-hourly 18"
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 75"
      "--keep-tag forever"
    ];
    backupPrepareCommand = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q ${homelabMediaPath}; then
        echo "Error: '${homelabMediaPath}' is not mounted. Skipping backup."
        exit 1 # Exit with a non-zero status to prevent the backup
      fi

      # Remove any stale locks.
      ${pkgs.restic}/bin/restic unlock || true

      ${lib.optionalString enableLEDs ''
      # Turn on Yellow LED to indicate backup is starting
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 17=1
      ''}

      echo "Backing up '${homelabMediaPath}'."
    '';
    backupCleanupCommand = ''
      ${lib.optionalString enableLEDs ''
      # Turn off LED now that backup is complete
      ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 17=0
      ''}
    '';
    timerConfig = {
      # OnCalendar = "0/6:00"; # Every 6 hours at minute 0
      OnCalendar = "0,6,12,18:00"; # Every day at 00:00, 06:00, 12:00, and 18:00
      Persistent = true;
    };
  };

  systemd.services."restic-backups-homelab@keyberry".serviceConfig.ExecStopPost = lib.mkAfter [
    "${ping-uptime-kuma-keyberry}/bin/ping-uptime-kuma@restic-backups-homelab@keyberry"
  ];
}
