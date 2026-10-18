{ config, lib, pkgs, ... }:

let
  # Pushed to pilab, whose daily restic job carries everything under
  # /media/HOMELAB_MEDIA/services on to keyberry. Same setup as chocomelt.
  pilabId = "4ZGXF3T-AU3D6ZJ-JO4UQYO-O6TD5VT-KXB5XAA-BFMWMI7-Y7BFEFK-TUAIEA3";
  dbCopy = "/var/lib/hass-db";

  mkFolder = id: label: path: ignorePatterns: {
    inherit id label path ignorePatterns;
    devices = [ "pilab" ];
    # sendonly: radrubble is the source of truth; nothing on pilab can
    # propagate back into live service state here.
    type = "sendonly";
  };
in
{
  # Pinned identity (device KSDDWRZ-...). radrubble's previous identity
  # went to chocomelt along with the media stack.
  sops.secrets."syncthing.cert" = {};
  sops.secrets."syncthing.key" = {};

  services.syncthing = {
    enable = true;
    cert = config.sops.secrets."syncthing.cert".path;
    key = config.sops.secrets."syncthing.key".path;

    # Root, because /var/lib/hass is 0700 hass.
    user = "root";
    group = "root";
    dataDir = "/var/lib/syncthing";
    configDir = "/var/lib/syncthing/.config/syncthing";

    openDefaultPorts = false;
    # Loopback only - reach it with `ssh -L 8384:localhost:8384 radrubble`.
    guiAddress = "127.0.0.1:8384";

    settings = {
      devices.pilab = {
        id = pilabId;
        autoAcceptFolders = false;
      };

      folders = {
        "radrubble-hass" = mkFolder "radrubble-hass" "Home Assistant" "/var/lib/hass" [
          # The live database is never consistent on disk while HA runs;
          # radrubble-hass-db carries a nightly snapshot instead.
          "/home-assistant_v2.db"
          "/home-assistant_v2.db-wal"
          "/home-assistant_v2.db-shm"
          "/home-assistant.log*"
          "/.ha_run.lock"
          # HA's own encrypted daily backups: they duplicate the database
          # and, being encrypted, defeat restic's deduplication.
          "/backups"
          "/.cache"
          "/deps"
          "/tts"
          "__pycache__"
        ];
        "radrubble-hass-db" = mkFolder "radrubble-hass-db" "Home Assistant database" dbCopy [
          # In-progress copy and its rollback journal.
          "*.tmp*"
        ];
      };
    };
  };

  systemd.tmpfiles.rules = [ "d ${dbCopy} 0700 root root -" ];

  # VACUUM INTO reads the whole database in one transaction, so HA's writes
  # cannot restart it the way they restart sqlite3's `.backup`. Scheduled
  # after the 04:12 recorder trim and well before pilab's 07:00 restic run.
  systemd.services.hass-db-copy = {
    description = "Consistent copy of the Home Assistant database for syncthing";
    startAt = "04:45";
    path = [ pkgs.sqlite ];
    serviceConfig.Type = "oneshot";
    script = ''
      rm -f ${dbCopy}/home-assistant_v2.db.tmp
      sqlite3 /var/lib/hass/home-assistant_v2.db "VACUUM INTO '${dbCopy}/home-assistant_v2.db.tmp'"
      mv ${dbCopy}/home-assistant_v2.db.tmp ${dbCopy}/home-assistant_v2.db
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
  };

  # The NixOS module defaults to PrivateUsers=yes, which makes root appear as
  # an unprivileged UID and prevents reading /var/lib/hass.
  systemd.services.syncthing.serviceConfig.PrivateUsers = lib.mkForce false;
}
