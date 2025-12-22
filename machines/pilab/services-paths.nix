{ everythingElsePath, homelabMediaPath, ... }:

let
  services = {
    home-assistant = {
      configSource = "/var/lib/hass";
      configBackup = "${homelabMediaPath}/services/hass";
    };

    radarr = {
      configSource = "${everythingElsePath}/arr/configs/radarr";
      configBackup = "${homelabMediaPath}/services/arr/radarr/config";
    };
    sonarr = {
      configSource = "${everythingElsePath}/arr/configs/sonarr";
      configBackup = "${homelabMediaPath}/services/arr/sonarr/config";
    };
    bazarr = {
      configSource = "${everythingElsePath}/arr/configs/bazarr";
      configBackup = "${homelabMediaPath}/services/arr/bazarr/config";
    };
    prowlarr = {
      configSource = "${everythingElsePath}/arr/configs/prowlarr";
      configBackup = "${homelabMediaPath}/services/arr/prowlarr/config";
    };
    jellyseerr = {
      configSource = "${everythingElsePath}/arr/configs/jellyseerr";
      configBackup = "${homelabMediaPath}/services/arr/jellyseerr/config";
    };
    jellyfin = {
      configSource = "${everythingElsePath}/arr/configs/jellyfin";
      configBackup = "${homelabMediaPath}/services/arr/jellyfin/config";
    };
    qbittorrent = {
      configSource = "${everythingElsePath}/qbittorrent/config";
      configBackup = "${homelabMediaPath}/services/qbittorrent/config";
    };
  };
in
{
  _module.args.servicePaths = services;
}
