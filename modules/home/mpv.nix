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
      osc = "no";
    };
    scripts = with pkgs; [
      mpvScripts.mpv-cheatsheet
      mpvScripts.mpris
      mpvScripts.webtorrent-mpv-hook
      mpvScripts.thumbnail
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
