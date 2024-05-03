{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    theme = "Dracula";
    # extraConfig = builtins.readFile ../chezmoi/dot_wezterm.lua;
    # font = {
    #   name = "FantasqueSansM Nerd Font Mono";
    #   size = 12.2;
    # };
    shellIntegration = {
      enableZshIntegration = true;
      mode = "no-cursor";
    };
    settings = {
      cursor_shape = "block";
      cursor_blink_interval = 0;
      font_family = "FantasqueSansM Nerd Font";
      bold_font = "FantasqueSansM Nerd Font Bold";
      italic_font = "FantasqueSansM Nerd Font Italic";
      bold_italic_font = "FantasqueSansM Nerd Font Bold Italic";
      enable_audio_bell = false;
      font_size = "12.2";
    };
  };
}
