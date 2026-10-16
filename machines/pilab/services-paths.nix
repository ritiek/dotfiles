{ everythingElsePath, homelabMediaPath, ... }:

let
  services = {
    # home-assistant (/var/lib/hass) and hermes (/var/lib/hermes) moved to
    # radrubble, out of lsyncd's reach. The last copies stay under
    # ${homelabMediaPath}/services/{hass,hermes}.

    # The *arr stack, jellyfin and qbittorrent moved to chocomelt along with
    # the EVERYTHING_ELSE drive, so lsyncd can no longer reach their configs
    # from pilab. They now replicate onto ${homelabMediaPath}/services/... via
    # syncthing (see machines/chocomelt/services/syncthing.nix), and restic
    # picks them up from there like everything else under services/.
    #
    # Kept commented rather than deleted: if the drive ever comes back to
    # pilab, uncommenting restores the old lsyncd behaviour.
    #
    # radarr = {
    #   configSource = "${everythingElsePath}/arr/configs/radarr";
    #   configBackup = "${homelabMediaPath}/services/arr/radarr";
    # };
    # sonarr = {
    #   configSource = "${everythingElsePath}/arr/configs/sonarr";
    #   configBackup = "${homelabMediaPath}/services/arr/sonarr";
    # };
    # bazarr = {
    #   configSource = "${everythingElsePath}/arr/configs/bazarr";
    #   configBackup = "${homelabMediaPath}/services/arr/bazarr";
    # };
    # prowlarr = {
    #   configSource = "${everythingElsePath}/arr/configs/prowlarr";
    #   configBackup = "${homelabMediaPath}/services/arr/prowlarr";
    # };
    # jellyseerr = {
    #   configSource = "${everythingElsePath}/arr/configs/jellyseerr";
    #   configBackup = "${homelabMediaPath}/services/arr/jellyseerr";
    # };
    # jellyfin = {
    #   configSource = "${everythingElsePath}/arr/configs/jellyfin";
    #   configBackup = "${homelabMediaPath}/services/arr/jellyfin";
    # };
    # qbittorrent = {
    #   configSource = "${everythingElsePath}/qbittorrent/config";
    #   configBackup = "${homelabMediaPath}/services/qbittorrent/config";
    # };
  };
in
{
  _module.args.servicePaths = services;
}
