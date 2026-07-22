{ config, lib, pkgs, everythingElsePath, ... }:

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
  nixarr = {
    enable = true;

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
      # Deliberately not setting extraConfig/serverConfig: leaving it empty
      # means nixpkgs never touches the migrated qBittorrent.conf, so all
      # pre-existing settings (save paths, categories, RSS feeds, WebUI port)
      # persist untouched. qui (nixarr's default modern WebUI) is left
      # enabled at its default port.
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
  systemd.tmpfiles.rules = [
    "Z ${arrConfigs}/radarr - radarr media - -"
    "Z ${arrConfigs}/sonarr - sonarr media - -"
    "Z ${arrConfigs}/bazarr - bazarr media - -"
    "Z ${arrConfigs}/prowlarr - prowlarr prowlarr - -"
    "Z ${arrConfigs}/jellyseerr - seerr seerr - -"
    "Z ${arrConfigs}/jellyfin - jellyfin media - -"
    "Z ${qbtConfig} - qbittorrent media - -"

    "Z ${everythingElsePath}/arr/movies 2775 root media - -"
    "Z ${everythingElsePath}/arr/tv 2775 root media - -"
    "Z ${everythingElsePath}/qbittorrent/downloads 2775 root media - -"

    # Jellyfin's on-disk library-folder markers ("*.mblink" files, plain
    # text files containing an absolute path) still reference pilab's old
    # docker-internal library paths. If left pointing at a path that
    # doesn't exist, Jellyfin's startup validation silently prunes the
    # whole library (CollectionFolder row + all its AncestorIds hierarchy
    # links, via ON DELETE CASCADE) on every boot. Force-write the correct,
    # real paths every time EVERYTHING_ELSE is mounted so this self-heals
    # instead of breaking again on the next reboot.
    "F ${arrConfigs}/jellyfin/data/root/default/Movies/movies.mblink - - - - ${everythingElsePath}/arr/movies"
    "F ${arrConfigs}/jellyfin/data/root/default/Shows/tvshows.mblink - - - - ${everythingElsePath}/arr/tv"
  ];

  # Nothing should autostart at boot -- everything is started explicitly via
  # `sudo mediaserver-start` once EVERYTHING_ELSE is mounted.
  systemd.services = lib.genAttrs (map (lib.removeSuffix ".service") units) (_: {
    wantedBy = lib.mkForce [ ];
    unitConfig.RequiresMountsFor = requiredMounts;
  });

  # Auto-stop everything if EVERYTHING_ELSE is unplugged without running
  # `sudo mediaserver-stop` first. Deliberately no ACTION=="add" auto-start
  # rule -- starting is always explicit via `sudo mediaserver-start`.
  services.udev.extraRules = ''
    ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="EVERYTHING_ELSE", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl stop ${lib.concatStringsSep " " units}"
  '';
}
