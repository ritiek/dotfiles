{ config, ... }:
{
  # home-manager merges `settings` into the shim's writable conf.json on each
  # switch, and starts the shim with graphical-session.target.
  services.jellyfin-mpv-shim = {
    enable = true;
    # radrubble needs ~20-40s to start a transcode after a quality change;
    # with the 30s default the shim gives up and closes mpv.
    settings.playback_timeout = 120;
    mpvConfig = config.programs.mpv.config;
  };
}
