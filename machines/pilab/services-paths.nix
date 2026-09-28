{ everythingElsePath, homelabMediaPath, ... }:

let
  services = {
    home-assistant = {
      configSource = "/var/lib/hass";
      configBackup = "${homelabMediaPath}/services/hass";
    };

    hermes = {
      configSource = "/var/lib/hermes";
      configBackup = "${homelabMediaPath}/services/hermes";
      # Reinstallable / regenerable bulk: takes 8.1G -> ~1.5G.
      exclude = [
        ".hermes/local-packages"
        ".hermes/cache"
        ".hermes/logs"
        ".hermes/lsp"
        ".cache"
        ".npm"
      ];
    };

    # The *arr stack, jellyfin and qbittorrent moved to radrubble along with
    # the EVERYTHING_ELSE drive, so lsyncd can no longer reach their configs
    # from pilab. They now replicate onto ${homelabMediaPath}/services/... via
    # syncthing (see machines/radrubble/services/syncthing.nix), and restic
    # picks them up from there like everything else under services/.
    #
    # Kept commented rather than deleted: if the drive ever comes back to
    # pilab, uncommenting restores the old lsyncd behaviour.
    #
    # radarr = {
    #   configSource = "${everythingElsePath}/arr/configs/radarr";
    #   configBackup = "${homelabMediaPath}/services/arr/radarr/config";
    # };
    # sonarr = {
    #   configSource = "${everythingElsePath}/arr/configs/sonarr";
    #   configBackup = "${homelabMediaPath}/services/arr/sonarr/config";
    # };
    # bazarr = {
    #   configSource = "${everythingElsePath}/arr/configs/bazarr";
    #   configBackup = "${homelabMediaPath}/services/arr/bazarr/config";
    # };
    # prowlarr = {
    #   configSource = "${everythingElsePath}/arr/configs/prowlarr";
    #   configBackup = "${homelabMediaPath}/services/arr/prowlarr/config";
    # };
    # jellyseerr = {
    #   configSource = "${everythingElsePath}/arr/configs/jellyseerr";
    #   configBackup = "${homelabMediaPath}/services/arr/jellyseerr/config";
    # };
    # jellyfin = {
    #   configSource = "${everythingElsePath}/arr/configs/jellyfin";
    #   configBackup = "${homelabMediaPath}/services/arr/jellyfin/config";
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
