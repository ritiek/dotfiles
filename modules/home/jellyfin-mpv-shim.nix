{ config, pkgs, ... }:
{
  # home-manager merges `settings` into the shim's writable conf.json on each
  # switch, and starts the shim with graphical-session.target.
  services.jellyfin-mpv-shim = {
    enable = true;
    # Fix keybindings dying while external subtitles load after a quality
    # change: load them asynchronously. Upstream: jellyfin/jellyfin-mpv-shim#343.
    package = pkgs.jellyfin-mpv-shim.overridePythonAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.writeText "jellyfin-mpv-shim-async-sub.patch" ''
          --- a/jellyfin_mpv_shim/player.py
          +++ b/jellyfin_mpv_shim/player.py
          @@ -4795,15 +4795,22 @@
                   if sub_id in self.external_subtitles:
                       self._player.sub = self.external_subtitles[sub_id]
                   else:
          -            try:
          -                sub_url = self._video.subtitle_url[sub_id]
          -                if settings.log_decisions:
          -                    log.info("Load External Subtitle: {0}".format(sub_url))
          -                self._player.sub_add(sub_url)
          -                self.external_subtitles[sub_id] = self._player.sub
          -                self.external_subtitles_rev[self._player.sub] = sub_id
          -            except SystemError:
          -                log.info("PlayerManager::could not load external subtitle")
          +            sub_url = self._video.subtitle_url[sub_id]
          +            if settings.log_decisions:
          +                log.info("Load External Subtitle: {0}".format(sub_url))
          +            # When transcoding, Jellyfin extracts subtitles by reading the whole
          +            # file, which can take minutes. A blocking sub_add would hold _lock
          +            # (and so every keybinding) that long, so load asynchronously.
          +            subs, subs_rev = self.external_subtitles, self.external_subtitles_rev
          +
          +            def loaded(error, _result):
          +                if error:
          +                    log.info("PlayerManager::could not load external subtitle")
          +                    return
          +                subs[sub_id] = self._player.sub
          +                subs_rev[self._player.sub] = sub_id
          +
          +            self._player.command_async("sub-add", sub_url, callback=loaded)
           
           
           
        '')
      ];
    });
    # radrubble needs ~20-40s to start a transcode after a quality change;
    # with the 30s default the shim gives up and closes mpv.
    settings.playback_timeout = 120;
    mpvConfig = config.programs.mpv.config // {
      # After a quality change Jellyfin extracts subtitles from the whole file
      # before serving them (~60s+ on radrubble); mpv's 60s default gives up.
      network-timeout = 300;
    };
  };
}
