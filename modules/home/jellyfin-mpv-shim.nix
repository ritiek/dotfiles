{ config, lib, pkgs, ... }:
{
  # home-manager merges `settings` into the shim's writable conf.json on each
  # switch. The shim is started on demand from the desktop entry below.
  services.jellyfin-mpv-shim = {
    enable = true;
    # radrubble needs ~20-40s to start a transcode after a quality change;
    # with the 30s default the shim gives up and closes mpv.
    settings.playback_timeout = 120;
    # Auto-hide the playback HUD after 2s of no input (default 4s).
    settings.hud_hide_secs = 2.0;
    mpvConfig = config.programs.mpv.config // {
      # After a quality change Jellyfin extracts subtitles from the whole file
      # before serving them (~60s+ on radrubble); mpv's 60s default gives up.
      network-timeout = 300;
    };
  };

  # Log the shim in to chocomelt's Jellyfin when it has no saved login yet.
  # The shim's GUI mode ignores --server/--username/--password, so this calls
  # its own login API; the token then lives in ~/.config/jellyfin-mpv-shim/users.json.
  sops.secrets."jellyfin.url" = { };
  sops.secrets."jellyfin.username" = { };
  sops.secrets."jellyfin.password" = { };
  systemd.user.services.jellyfin-mpv-shim = {
    Unit.After = [ "sops-nix.service" ];
    Install.WantedBy = lib.mkForce [ ];
    # "-": a failed login (server or network down) must not stop the shim.
    Service.ExecStartPre = "-${pkgs.writers.writePython3 "jellyfin-mpv-shim-login" {
      libraries = [ (pkgs.python3Packages.toPythonModule config.services.jellyfin-mpv-shim.package) ];
      # Interpolated secret paths vary in length per host.
      flakeIgnore = [ "E501" ];
    } ''
      import os
      from jellyfin_mpv_shim.clients import clientManager


      def secret(path):
          with open(path) as f:
              return f.read().strip()


      user = secret("${config.sops.secrets."jellyfin.username".path}")
      clientManager.load_credentials()
      if not any(c.get("username") == user for c in clientManager.credentials):
          ok = clientManager.login(
              secret("${config.sops.secrets."jellyfin.url".path}").rstrip("/"),
              user,
              secret("${config.sops.secrets."jellyfin.password".path}"),
          )
          print("login ok" if ok else "login failed", flush=True)
      # The shim leaves non-daemon threads running; exit without joining them.
      os._exit(0)
    ''}";
  };

  xdg.desktopEntries.jellyfin-mpv-shim = {
    name = "Jellyfin MPV Shim";
    comment = "Cast from Jellyfin to mpv";
    icon = "${config.services.jellyfin-mpv-shim.package}/share/icons/hicolor/128x128/apps/jellyfin-mpv-shim.png";
    # Through the unit so the login above runs first.
    exec = "systemctl --user start jellyfin-mpv-shim.service";
    categories = [ "AudioVideo" "Video" ];
  };
}
