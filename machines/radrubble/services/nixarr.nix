{ config, lib, pkgs, everythingElsePath, ... }:

let
  # qBittorrent's systemd service runs with a minimal PATH (coreutils/findutils/
  # gnugrep/gnused/systemd only, no curl), so writeShellApplication's PATH
  # wrapping (via runtimeInputs) is required for the script's `curl` call to
  # actually be found when qBittorrent invokes it as an AutoRun program.
  #
  # The Gotify token is never embedded in the script text: it's substituted
  # here with the sops-nix runtime secret *path* (not the secret value
  # itself -- that's only decrypted on-disk on radrubble at activation time,
  # long after this Nix expression is evaluated/built on alcove).
  qbNotifyScript = pkgs.writeShellApplication {
    name = "qbittorrent-notify";
    runtimeInputs = [ pkgs.curl ];
    text = builtins.replaceStrings
      [ "@GOTIFY_TOKEN_FILE@" ]
      [ config.sops.secrets."gotify.token".path ]
      (builtins.readFile ./qbittorrent-notify.sh);
  };
in

# Migrated from pilab's docker/oci-containers *arr stack. EVERYTHING_ELSE is
# the same LUKS-encrypted btrfs drive that used to be plugged into pilab,
# containing the existing Radarr/Sonarr/Bazarr/Prowlarr/qBittorrent/Jellyfin/
# Jellyseerr state (databases, configs, media, downloads) as-is.
#
# Nothing here auto-starts at boot: EVERYTHING_ELSE is mounted/unmounted
# imperatively via `sudo mediaserver-mount`/`mediaserver-unmount`
# (machines/radrubble/home/ritiek/default.nix), and services are started/
# stopped explicitly via `sudo mediaserver-start`/`mediaserver-stop`. A udev
# rule additionally stops everything if the drive is unplugged without
# running mediaserver-stop first.

let
  arrConfigs = "${everythingElsePath}/arr/configs";
  qbtConfig = "${everythingElsePath}/qbittorrent/config";

  # Nixarr's per-service systemd unit names (seerr.service, not
  # jellyseerr.service; qui.service is a separate WebUI proxy unit alongside
  # qbittorrent.service).
  units = [
    "radarr.service"
    "sonarr.service"
    "bazarr.service"
    "prowlarr.service"
    "qbittorrent.service"
    "qui.service"
    "jellyfin.service"
    "seerr.service"
  ];

  requiredMounts = [ everythingElsePath ];
in
{
  # Decrypted from the default system sops file (machines/radrubble/secrets.yaml).
  # Owned by qbittorrent since qbittorrent-notify.sh runs as that user (exec'd
  # directly by qBittorrent's AutoRun, not via a systemd EnvironmentFile).
  sops.secrets."gotify.token" = {
    owner = "qbittorrent";
  };

  nixarr = {
    enable = true;
    stateDir = "${everythingElsePath}/.state/nixarr";

    radarr = {
      enable = true;
      stateDir = "${arrConfigs}/radarr";
      openFirewall = true;
    };
    sonarr = {
      enable = true;
      stateDir = "${arrConfigs}/sonarr";
      openFirewall = true;
    };
    bazarr = {
      enable = true;
      stateDir = "${arrConfigs}/bazarr";
    };
    prowlarr = {
      enable = true;
      stateDir = "${arrConfigs}/prowlarr";
      openFirewall = true;
    };
    qbittorrent = {
      enable = true;
      stateDir = qbtConfig;
      openFirewall = true;
      # nixarr always sets services.qbittorrent.serverConfig non-empty,
      # which triggers an ExecStartPre that copies a store-generated
      # qBittorrent.conf, wiping any WebUI password changes on restart.
      # Setting WebUI credentials here keeps them stable across reboots.
      extraConfig = {
        Application = {
          # Restores pilab's old file-logging behaviour, pointed at the new
          # nixarr stateDir instead of the old docker /config path.
          "FileLogger\\Enabled" = true;
          "FileLogger\\Path" = "${qbtConfig}/qBittorrent/logs";
          "FileLogger\\Backup" = true;
          "FileLogger\\DeleteOld" = true;
          "FileLogger\\MaxSizeBytes" = 66560;
          "FileLogger\\Age" = 1;
          "FileLogger\\AgeType" = 1;
        };
        LegalNotice.Accepted = true;
        Network = {
          "PortForwardingEnabled" = false;
          "Cookies" = "@Invalid()";
        };
        Core.AutoDeleteAddedTorrentFile = "Never";
        BitTorrent = {
          # Restores pilab's old behaviour: no ratio/seeding-time limits (the
          # *arr apps manage removal) and torrents write directly to their
          # final folder instead of using a `.incomplete` staging path.
          "Session\\GlobalMaxRatio" = 1;
          "Session\\GlobalMaxSeedingMinutes" = 1;
          "Session\\GlobalMaxInactiveSeedingMinutes" = 1;
          "Session\\UseAlternativeGlobalSpeedLimit" = false;
          "Session\\TempPathEnabled" = false;
          # Override nixarr's default (${nixarr.mediaDir}/qbittorrent) to point
          # at the EVERYTHING_ELSE drive where the migrated data lives.
          "Session\\DefaultSavePath" = "${everythingElsePath}/qbittorrent/downloads";
          "Session\\TempPath" = "${everythingElsePath}/qbittorrent/downloads/.incomplete";
        };
        Preferences = {
          "WebUI\\Username" = "ritiek";
          "WebUI\\Password_PBKDF2" = "@ByteArray(cUIyMDI0Rml4ZWRTYWx0IQ==:80h/fCeBkAZDlBBCKCO0KWakgR4i6Lb0oFSSWUh/SHl8v71Yh/kLq3itEuqdopZhluGSIJsZmNeYwgDa4t03lA==)";
          "Connection\\UPnP" = false;
          "General\\Locale" = "en";
          "General\\StatusbarExternalIPDisplayed" = true;
          # Override nixarr's default download paths to use EVERYTHING_ELSE.
          "Downloads\\SavePath" = "${everythingElsePath}/qbittorrent/downloads";
          "Downloads\\TempPath" = "${everythingElsePath}/qbittorrent/downloads/.incomplete";
          "Downloads\\ScanDirsV2" = builtins.toJSON {
            "${everythingElsePath}/qbittorrent/downloads/.watch" = 0;
          };
        };
        AutoRun = {
          # qBittorrent re-saves its own preferences (including AutoRun) to
          # this file shortly after startup, and its serializer does not
          # round-trip quoted/multi-word Program arguments faithfully (it
          # drops the quotes and the spaces between placeholders). Keep the
          # title as a single unquoted token to avoid corrupting the args.
          "OnTorrentAdded\\Enabled" = true;
          "OnTorrentAdded\\Program" = "${qbNotifyScript}/bin/qbittorrent-notify Download_Added %N %L %G %F %D %C %Z %T %I";
          # qBittorrent's "run program on torrent finished" feature is a
          # legacy holdover with misleading naming: despite the symmetrical
          # OnTorrentAdded/* naming, it actually reads/writes the flat keys
          # AutoRun/enabled + AutoRun/program (lowercase, no "OnTorrentFinished"
          # segment at all) -- confirmed in qBittorrent's own source
          # (src/base/preferences.cpp: isAutoRunOnTorrentFinishedEnabled()
          # reads "AutoRun/enabled", getAutoRunOnTorrentFinishedProgram()
          # reads "AutoRun/program"). Setting "OnTorrentFinished\Enabled"/
          # "OnTorrentFinished\Program" here was a no-op: qBittorrent never
          # reads those keys, so the finished-notification silently never fired.
          "enabled" = true;
          "program" = "${qbNotifyScript}/bin/qbittorrent-notify Download_Finished %N %L %G %F %D %C %Z %T %I";
        };
        RSS.AutoDownloader = {
          "DownloadRepacks" = true;
          # Backslashes are doubled: qBittorrent's underlying QSettings INI
          # reader silently drops `\<letter>` sequences it doesn't recognize
          # as an escape (e.g. `\d`, `\-`), so a literal single backslash
          # needs to be written as `\\` to survive the round-trip.
          "SmartEpisodeFilter" = ''s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"'';
        };
      };
    };
    jellyfin.enable = true;
    seerr = {
      enable = true;
      stateDir = "${arrConfigs}/jellyseerr";
      openFirewall = true;
    };
  };

  # Nixarr forces a 4-subdir stateDir layout (log/cache/data/config) under
  # nixarr.jellyfin.stateDir. The migrated pilab data already has separate
  # {data,cache,log} subdirs but its XML configs sit at the TOP LEVEL of
  # arr/configs/jellyfin (no extra "config" nesting) -- point services.jellyfin
  # directly at the existing layout instead of nixarr's stateDir convention.
  services.jellyfin = {
    configDir = lib.mkForce "${arrConfigs}/jellyfin";
    dataDir = lib.mkForce "${arrConfigs}/jellyfin/data";
    cacheDir = lib.mkForce "${arrConfigs}/jellyfin/cache";
    logDir = lib.mkForce "${arrConfigs}/jellyfin/log";
    openFirewall = lib.mkForce true;
  };

  # Self-healing ownership fixups for the migrated pilab data: nixarr's
  # hardcoded per-service UIDs (radarr=275, sonarr=274, bazarr=232,
  # prowlarr=293, qbittorrent=72, jellyfin=146, seerr=262, group media=169)
  # don't match pilab's docker UIDs (1000, or 4311 for jellyfin).
  # systemd-tmpfiles-setup.service only runs once at boot, before
  # EVERYTHING_ELSE is mounted, so `mediaserver-mount` re-runs
  # `systemd-tmpfiles --create` after mounting to apply these every time.
  #
  # Uses the structured `systemd.tmpfiles.settings` form (typed
  # mode/user/group/argument fields) instead of positional rule strings.
  systemd.tmpfiles.settings."nixarr-radrubble" = {
    "${arrConfigs}/radarr".Z = { user = "radarr"; group = "media"; };
    "${arrConfigs}/sonarr".Z = { user = "sonarr"; group = "media"; };
    "${arrConfigs}/bazarr".Z = { user = "bazarr"; group = "media"; };
    "${arrConfigs}/prowlarr".Z = { user = "prowlarr"; group = "prowlarr"; };
    "${arrConfigs}/jellyseerr".Z = { user = "seerr"; group = "seerr"; };
    "${arrConfigs}/jellyfin".Z = { user = "jellyfin"; group = "media"; };
    "${qbtConfig}".Z = { user = "qbittorrent"; group = "media"; };

    "${everythingElsePath}/arr/movies".Z = { mode = "2775"; user = "root"; group = "media"; };
    "${everythingElsePath}/arr/tv".Z = { mode = "2775"; user = "root"; group = "media"; };
    "${everythingElsePath}/qbittorrent/downloads".Z = { mode = "2775"; user = "root"; group = "media"; };

    # Sonarr/Radarr root folders reference bare /tv and /movies from the
    # docker era, but those paths don't exist on the host. Create symlinks
    # so the *arr UIs don't show PermissionError in the root-folder picker.
    # `L+` removes any stale directory (e.g. an empty /tv created by Sonarr's
    # health check stub) and replaces it with the symlink.
    "/tv"."L+".argument = "${everythingElsePath}/arr/tv";
    "/movies"."L+".argument = "${everythingElsePath}/arr/movies";

    # Jellyfin's on-disk library-folder markers ("*.mblink" files, plain
    # text files containing an absolute path) still reference pilab's old
    # docker-internal library paths. If left pointing at a path that
    # doesn't exist, Jellyfin's startup validation silently prunes the
    # whole library (CollectionFolder row + all its AncestorIds hierarchy
    # links, via ON DELETE CASCADE) on every boot. Force-write the correct,
    # real paths every time EVERYTHING_ELSE is mounted so this self-heals
    # instead of breaking again on the next reboot.
    "${arrConfigs}/jellyfin/data/root/default/Movies/movies.mblink".F.argument = "${everythingElsePath}/arr/movies";
    "${arrConfigs}/jellyfin/data/root/default/Shows/tvshows.mblink".F.argument = "${everythingElsePath}/arr/tv";
  };

  # Nothing should autostart at boot -- everything is started explicitly via
  # `sudo mediaserver-start` once EVERYTHING_ELSE is mounted.
  #
  # Additionally, qBittorrent gets a preStart hook (see below): its
  # single-instance guard (its vendored QtLocalPeer) writes a `lockfile`
  # containing its PID into the config dir. The file persists on the
  # EVERYTHING_ELSE drive across reboots, and after a reboot the recorded PID
  # can be reused by any unrelated process. When that happens,
  # qbittorrent-nox takes the hasAnotherInstance() path in main.cpp and exits
  # 0 *silently* (the "Another qBittorrent instance is already running"
  # message only prints when argc == 1, and systemd passes arguments), so the
  # service dies within seconds of `mediaserver-start` with no failure
  # anywhere -- only 4 lines in qBittorrent's own file log show the early
  # shutdown. First hit 2026-08-30: the lockfile held PID 3305 from the last
  # pre-reboot run, which the next boot assigned to [kworker/R-btrfs-fixup].
  #
  # systemd already guarantees only one instance of this unit exists, so
  # dropping any stale lockfile before start is safe. Implemented as preStart
  # (not an extra ExecStartPre) because nixpkgs' qbittorrent module defines
  # ExecStartPre as a bare string, which a second definition would clobber.
  systemd.services = lib.recursiveUpdate
    (lib.genAttrs (map (lib.removeSuffix ".service") units) (_: {
      wantedBy = lib.mkForce [ ];
      unitConfig.RequiresMountsFor = requiredMounts;
    }))
    {
      qbittorrent.preStart =
        "${pkgs.coreutils}/bin/rm -f ${qbtConfig}/qBittorrent/config/lockfile";
    };

  # Auto-stop everything if EVERYTHING_ELSE is unplugged without running
  # `sudo mediaserver-stop` first. Deliberately no ACTION=="add" auto-start
  # rule -- starting is always explicit via `sudo mediaserver-start`.
  services.udev.extraRules = ''
    ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="EVERYTHING_ELSE", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl stop ${lib.concatStringsSep " " units}"
  '';
}
