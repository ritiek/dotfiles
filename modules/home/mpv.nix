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
      # Pass magnet URLs to mpv.
      # TODO: Switch to unstable once this PR is merged:
      # https://github.com/NixOS/nixpkgs/pull/350461
      stable.mpvScripts.webtorrent-mpv-hook
      mpvScripts.thumbnail
      mpvScripts.thumbfast
      # Doesn't install for some reason.
      # mpvScripts.mpv-notify-send
    ];
  };
}
