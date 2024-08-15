{ pkgs, ... }:
{
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
      hwdec = "auto-safe";
      vo = "gpu";
      profile = "gpu-hq";
      gpu-context = "wayland";
      osc = "no";
    };
    scripts = with pkgs.mpvScripts; [
      mpv-cheatsheet
      mpris
      # Pass magnet URLs to mpv.
      webtorrent-mpv-hook
      thumbnail
      thumbfast
      # Doesn't install for some reason.
      # mpv-notify-send
    ];
  };
}
