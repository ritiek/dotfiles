{ config, pkgs, ... }:
{
  # home-manager merges `settings` into the shim's writable conf.json on each
  # switch, and starts the shim with graphical-session.target.
  services.jellyfin-mpv-shim = {
    enable = true;
    # Fix dead keybindings and missing subtitles after a quality change:
    # load external subtitles asynchronously, and run key handlers off the
    # mpv event thread. Upstream: jellyfin/jellyfin-mpv-shim#343, #223.
    package = pkgs.jellyfin-mpv-shim.overridePythonAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.writeText "jellyfin-mpv-shim-async-sub.patch" ''
          --- a/jellyfin_mpv_shim/player.py
          +++ b/jellyfin_mpv_shim/player.py
          @@ -1017,15 +1017,22 @@
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
           
               @synchronous("_lock")
               def toggle_fullscreen(self):
        '')
        (pkgs.writeText "jellyfin-mpv-shim-keys-off-event-thread.patch" ''
          --- a/jellyfin_mpv_shim/player.py
          +++ b/jellyfin_mpv_shim/player.py
          @@ -271,10 +271,13 @@
                       self._player.resume_playback = False
           
                   # Wrapper for on_key_press that ignores None.
          +        # Handlers run on the action thread: many take _lock, and running
          +        # them on the mpv event thread deadlocks with _play_media, which holds
          +        # _lock while waiting for an event (e.g. a keypress while loading).
                   def keypress(key):
                       def wrapper(func):
                           if key is not None:
          -                    self._player.on_key_press(key)(func)
          +                    self._player.on_key_press(key)(lambda: self.put_task(func))
                           return func
           
                       return wrapper
          @@ -529,7 +532,7 @@
                                   return
                               self.menu.mouse_select(int(args[1]))
                           elif args[0] == "shim-menu-click":
          -                    self.menu.menu_action("ok")
          +                    self.put_task(self.menu.menu_action, "ok")
                           elif args[0] == "shim-close":
                               log.info("Received shim-close message")
                               if self._video and not self._player.playback_abort:
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
