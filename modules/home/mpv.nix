{ pkgs, ... }:
{
  # home.packages = with pkgs; [
  #   mpv
  # ];
  programs.mpv = {
    enable = true;
    config = {
      sub-font = "Noto Sans Regular";
      sub-font-size = 38;
      sid = 2;
      alang = "jpn";
      slang = "eng";
      no-sub-ass = "";
      force-seekable = "";
      # hwdec = "auto-safe";
      # vo = "gpu";
      # profile = "gpu-hq";
      # gpu-context = "wayland";
      osc = "yes";
      gamma = 10;
    };
    scripts = with pkgs; [
      mpvScripts.mpv-cheatsheet
      mpvScripts.mpris
      mpvScripts.webtorrent-mpv-hook
      # XXX: Commenting for now cause this results in the following error:
      # [file] Cannot open file '/nix/store/g7n76rhfna3ndpwjbpn5b7im9h5ff7li-mpv-thumbnail-script-0.5.4/share/mpv/scripts/mpv_thumbnail_script_{client_osc,server}.lua': No such file or directory
      # Failed to open /nix/store/g7n76rhfna3ndpwjbpn5b7im9h5ff7li-mpv-thumbnail-script-0.5.4/share/mpv/scripts/mpv_thumbnail_script_{client_osc,server}.lua.
      # [mpv_thumbnail_script__client_osc_server_]
      # [mpv_thumbnail_script__client_osc_server_] stack traceback:
      # [mpv_thumbnail_script__client_osc_server_]      [C]: in ?
      # [mpv_thumbnail_script__client_osc_server_]      [C]: in ?
      # [mpv_thumbnail_script__client_osc_server_] Lua error: Could not read file.
      # [mpv_thumbnail_script__client_osc_server_]
      # client removed during hook handling
      #
      # mpvScripts.thumbnail

      mpvScripts.thumbfast
      # mpvScripts.autosub  # Temporarily disabled due to subliminal build issues
      mpvScripts.mpv-notify-send
    ];
  };

  xdg.mimeApps = {
    associations.added = {
      "audio/mpeg" = [ "mpv.desktop" ];
      "video/mp4" = [ "mpv.desktop" ];
      "video/x-matroska"= [ "mpv.desktop" ];
      "audio/x-wav" = [ "mpv.desktop" ];
      "audio/flac" = [ "mpv.desktop" ];
    };
    defaultApplications = {
      "audio/mpeg" = [ "mpv.desktop" ];
      "video/mp4" = [ "mpv.desktop" ];
      "video/x-matroska"= [ "mpv.desktop" ];
      "audio/x-wav" = [ "mpv.desktop" ];
      "audio/flac" = [ "mpv.desktop" ];
    };
  };
}
