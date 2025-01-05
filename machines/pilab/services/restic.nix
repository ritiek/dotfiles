{ config, pkgs, ...}:

{
  sops.secrets."restic.homelab.password" = {};
  # sops.secrets."restic.homelab.password".owner = "restic";

  users.groups.restic = {};
  users.users.restic = {
    uid = config.ids.uids.restic;
    # group = "root";
    group = "restic";
    # isNormalUser = true;
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
      "/media/HOMELAB_MEDIA"
    ];
    # exclude = [
    #   "*.db-shm"
    #   "*.db-wal"
    #   "LOCK"
    #   "media.lock"
    #   "migration_lock"
    # ];
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
      if ! ${pkgs.util-linux}/bin/mountpoint -q "/media/HOMELAB_MEDIA"; then
        echo "Error: '/media/HOMELAB_MEDIA' is not mounted. Skipping backup."
        exit 1 # Exit with a non-zero status to prevent the backup
      fi

      # Remove any stale locks.
      ${pkgs.restic}/bin/restic unlock || true

      echo "Backing up '/media/HOMELAB_MEDIA'."
    '';
    backupCleanupCommand = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q "/media/HOMELAB_MEDIA"; then
        echo "Error: '/media/HOMELAB_MEDIA' is not mounted. Skipping post backup cleanup."
        exit 1 # Exit with a non-zero status to prevent the post backup cleanup
      fi

      if ! ${pkgs.util-linux}/bin/mountpoint -q "${config.fileSystems.restic-backup.mountPoint}"; then
        echo "Error: '${config.fileSystems.restic-backup.mountPoint}' is not mounted. Skipping post backup cleanup."
        exit 1 # Exit with a non-zero status to prevent the post backup cleanup
      fi

      echo "Assigning ownership to 'restic:restic' on '${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA'."
      chown -R restic:restic "${config.fileSystems.restic-backup.mountPoint}/HOMELAB_MEDIA"
    '';
    timerConfig = {
      # Every 20 minutes
      OnCalendar = "*:0/20";
      Persistent = true;
    };
  };

  sops.secrets = {
    "restic.stashy.repository" = {};
    "restic.stashy.password" = {};
  };
  services.restic.backups.stashy = {
    initialize = true;
    repositoryFile = config.sops.secrets."restic.stashy.repository".path;
    passwordFile = config.sops.secrets."restic.stashy.password".path;
    # user = "restic";
    paths = [
      "/media/HOMELAB_MEDIA/services/spotdl/English Mix"
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
      ${pkgs.restic}/bin/restic unlock || true
    '';
    timerConfig = {
      OnCalendar = "*:0/20";
      Persistent = true;
    };
  };

  sops.secrets."restic.zerostash.repository" = {};
  # sops.secrets."restic.zerostash.repository".owner = "restic";
  services.restic.backups."homelab@zerostash" = {
    initialize = true;
    repositoryFile = config.sops.secrets."restic.zerostash.repository".path;
    passwordFile = config.sops.secrets."restic.homelab.password".path;
    # user = "restic";
    paths = [
      "/media/HOMELAB_MEDIA"
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
      if ! ${pkgs.util-linux}/bin/mountpoint -q "/media/HOMELAB_MEDIA"; then
        echo "Error: '/media/HOMELAB_MEDIA' is not mounted. Skipping backup."
        exit 1 # Exit with a non-zero status to prevent the backup
      fi

      # Remove any stale locks.
      ${pkgs.restic}/bin/restic unlock || true

      echo "Backing up '/media/HOMELAB_MEDIA'."
    '';
    timerConfig = {
      OnCalendar = "*:0/20";
      Persistent = true;
    };
  };
}