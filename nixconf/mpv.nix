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
    };
  };
}
