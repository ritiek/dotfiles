{ pkgs, ... }:
{
  programs.sioyek = {
    enable = true;
    config = {
      "startup_commands" = "toggle_statusbar";
      "default_dark_mode" = "1";
      "should_launch_new_window" = "1";
    };
  };
}
