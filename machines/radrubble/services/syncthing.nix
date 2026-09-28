{ config, lib, everythingElsePath, ... }:

let
  arrConfigs = "${everythingElsePath}/arr/configs";
  qbtConfig = "${everythingElsePath}/qbittorrent/config";

  # pilab is the only peer. It receives everything and is responsible for
  # pushing it onwards to keyberry (and pilab/zerostash once those are back)
  # via its existing restic jobs, since all of these land under
  # /media/HOMELAB_MEDIA/services which restic already snapshots.
  pilabId = "4ZGXF3T-AU3D6ZJ-JO4UQYO-O6TD5VT-KXB5XAA-BFMWMI7-Y7BFEFK-TUAIEA3";

  # Shared across the three .NET *arr apps: rolling text logs, the separate
  # logs database, cached poster art, and the SQLite sidecars. The sidecars
  # are excluded deliberately - copying a -wal/-shm without its parent .db
  # mid-write is worse than not copying it at all. The weekly Backups/*.zip
  # each app produces is a consistent dump and IS synced.
  arrIgnores = [
    "logs"
    "logs.db"
    "logs.db-shm"
    "logs.db-wal"
    "MediaCover"
    "*.db-shm"
    "*.db-wal"
  ];

  mkFolder = id: path: ignorePatterns: {
    inherit id path ignorePatterns;
    enable = true;
    devices = [ "pilab" ];
    # sendonly: radrubble is the source of truth. This makes it structurally
    # impossible for an empty or half-provisioned directory on pilab to
    # propagate back and delete live service state here.
    type = "sendonly";
  };
in
{
  services.syncthing = {
    enable = true;

    # Must be root. The arr config directories are mode 0700 owned by each
    # service's own user (e.g. `drwx------ jellyfin media`), so adding
    # syncthing to the `media` group would not grant read access.
    # Matches the keyberry and clawsiecats setups.
    user = "root";
    group = "root";
    dataDir = "/var/lib/syncthing";
    configDir = "/var/lib/syncthing/.config/syncthing";

    # Ports are opened explicitly below; this would also open the discovery
    # broadcast ports we do not need on a tailnet-only link.
    openDefaultPorts = false;

    # Loopback only - reach it with `ssh -L 8384:localhost:8384 radrubble`.
    # No GUI password secret needed as a result.
    guiAddress = "127.0.0.1:8384";

    settings = {
      devices.pilab = {
        id = pilabId;
        # radrubble only ever pushes; it should not accept folders from pilab.
        autoAcceptFolders = false;
      };

      folders = {
        "radrubble-radarr" = mkFolder "radrubble-radarr" "${arrConfigs}/radarr" arrIgnores;
        "radrubble-sonarr" = mkFolder "radrubble-sonarr" "${arrConfigs}/sonarr" arrIgnores;

        # Definitions/ is the indexer definition set, re-downloaded on start.
        "radrubble-prowlarr" =
          mkFolder "radrubble-prowlarr" "${arrConfigs}/prowlarr"
            (arrIgnores ++ [ "Definitions" ]);

        "radrubble-bazarr" = mkFolder "radrubble-bazarr" "${arrConfigs}/bazarr" [
          "log"
          "cache"
          "restore"
          "db/*.db-shm"
          "db/*.db-wal"
          "config/releases.txt"
          "config/announcements.json"
        ];

        "radrubble-jellyseerr" = mkFolder "radrubble-jellyseerr" "${arrConfigs}/jellyseerr" [
          "logs"
          "cache"
          "anime-list.xml"
        ];

        # By far the largest source. What is kept is jellyfin.db (users,
        # passwords, watch state, resume positions, playlists), the top-level
        # *.xml config, data/root and data/plugins - roughly 400M.
        #
        # data/metadata is ~9G of scraped artwork and NFOs that Jellyfin will
        # re-fetch, and data/data/*.bak*/*.old are ~4.3G of stale migration
        # copies. data/data/backups holds the 1.7G manual webui export, which
        # is a one-off and not worth replicating.
        "radrubble-jellyfin" = mkFolder "radrubble-jellyfin" "${arrConfigs}/jellyfin" [
          "cache"
          "log"
          "data/metadata"
          "data/transcodes"
          "data/data/*.bak*"
          "data/data/*.old"
          "data/data/*.db-shm"
          "data/data/*.db-wal"
          "data/data/backups"
          "jellyfin/images"
          "jellyfin/transcodes"
          "rffmpeg/rffmpeg.log"
          ".cache"
          ".aspnet"
        ];

        # qBittorrent's own settings are already declarative via extraConfig,
        # but BT_backup (the active torrents and their resume data) is not.
        "radrubble-qbittorrent" = mkFolder "radrubble-qbittorrent" qbtConfig [
          "qBittorrent/logs"
          "qBittorrent/cache"
          "qBittorrent/data/logs"
          "qBittorrent/data/GeoDB"
        ];
      };
    };
  };

  # Sync protocol + local discovery. The link runs over tailscale, which is
  # not a trusted interface in this config, so these must be opened.
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
  };

  # The drive can be physically detached, so syncthing must not run without
  # it - an empty source directory on a sendonly folder would propagate
  # deletions to pilab.
  #
  # Deliberately only RequiresMountsFor, matching nixarr.nix. Naming
  # media-EVERYTHING_ELSE.mount in requires= would be wrong: that unit is
  # synthesised from /proc/self/mountinfo rather than declared via
  # fileSystems, so it evaluates to not-found whenever the drive is absent,
  # which yields a silent ConditionResult=no instead of a real failure.
  # That is the exact failure mode that left pilab's lsyncd dead for two
  # months. RequiresMountsFor is resolved against the path at runtime and
  # degrades honestly.
  systemd.services.syncthing.unitConfig.RequiresMountsFor = [ everythingElsePath ];
}
