{ config, lib, everythingElsePath, ... }:

let
  arrConfigs = "${everythingElsePath}/arr/configs";
  qbtConfig = "${everythingElsePath}/qbittorrent/config";

  # pilab is the only peer. It receives everything and is responsible for
  # pushing it onwards to keyberry (and pilab/zerostash once those are back)
  # via its existing restic jobs, since all of these land under
  # /media/HOMELAB_MEDIA/services which restic already snapshots.
  pilabId = "4ZGXF3T-AU3D6ZJ-JO4UQYO-O6TD5VT-KXB5XAA-BFMWMI7-Y7BFEFK-TUAIEA3";

  mkFolder = id: label: path: ignorePatterns: {
    inherit id label path ignorePatterns;
    enable = true;
    devices = [ "pilab" ];
    # sendonly: chocomelt is the source of truth. This makes it structurally
    # impossible for an empty or half-provisioned directory on pilab to
    # propagate back and delete live service state here.
    type = "sendonly";
  };
in
{
  # Pinned identity, so a reflash keeps the same device ID and pilab keeps
  # trusting it (device U7WLZFQ-...).
  sops.secrets."syncthing.cert" = {};
  sops.secrets."syncthing.key" = {};

  services.syncthing = {
    enable = true;
    cert = config.sops.secrets."syncthing.cert".path;
    key = config.sops.secrets."syncthing.key".path;

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

    # Loopback only - reach it with `ssh -L 8384:localhost:8384 chocomelt`.
    # No GUI password secret needed as a result.
    guiAddress = "127.0.0.1:8384";

    settings = {
      devices.pilab = {
        id = pilabId;
        # chocomelt only ever pushes; it should not accept folders from pilab.
        autoAcceptFolders = false;
      };

      folders = {
        # Every app under arr/configs in one folder. Unanchored patterns apply
        # to all apps; the rest are anchored to one app's subdirectory.
        #
        # SQLite -wal/-shm are excluded deliberately - copying a sidecar
        # without its parent .db mid-write is worse than not copying it.
        # Caches are small (~150M total) and are synced.
        "radrubble-arr" = mkFolder "radrubble-arr" "*arr Stack" arrConfigs [
          "*.db-shm"
          "*.db-wal"
          "logs"
          "logs.db"
          "/bazarr/log"
          "/bazarr/restore"
          "/bazarr/config/releases.txt"
          "/bazarr/config/announcements.json"
          "/jellyseerr/anime-list.xml"
          # Indexer definitions, re-downloaded on start.
          "/prowlarr/Definitions"
          # data/metadata is ~9G of scraped artwork Jellyfin re-fetches;
          # data/data/backups holds a one-off ~9G manual webui export.
          "/jellyfin/log"
          "/jellyfin/data/metadata"
          "/jellyfin/data/transcodes"
          "/jellyfin/data/data/*.bak*"
          "/jellyfin/data/data/*.old"
          "/jellyfin/data/data/backups"
          "/jellyfin/jellyfin/transcodes"
          "/jellyfin/rffmpeg/rffmpeg.log"
          "/jellyfin/.aspnet"
        ];

        # qBittorrent's own settings are already declarative via extraConfig,
        # but BT_backup (the active torrents and their resume data) is not.
        "radrubble-qbittorrent" = mkFolder "radrubble-qbittorrent" "qBittorrent" qbtConfig [
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

  # The NixOS module defaults to PrivateUsers=yes, which makes root appear as
  # an unprivileged UID and prevents access to the 0700 service config dirs.
  systemd.services.syncthing.serviceConfig.PrivateUsers = lib.mkForce false;

  # The drive can be physically detached, so syncthing must not run without
  # it - an empty source directory on a sendonly folder would propagate
  # deletions to pilab.
  #
  # RequiresMountsFor alone does not stop it: with no declared mount unit it
  # only orders after -.mount, and syncthing happily scanned the empty
  # mountpoint dirs on chocomelt. So, like nixarr.nix, nothing starts it at
  # boot (mediaserver-start does, after mounting) and the assert fails the
  # unit loudly if anything starts it while the drive is absent.
  systemd.services.syncthing = {
    wantedBy = lib.mkForce [ ];
    unitConfig.RequiresMountsFor = [ everythingElsePath ];
    unitConfig.AssertPathIsMountPoint = everythingElsePath;
  };
  # syncthing-init Requires= syncthing, so it would pull syncthing in at boot.
  systemd.services.syncthing-init.wantedBy = lib.mkForce [ ];
}
