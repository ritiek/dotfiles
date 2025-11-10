{
  programs.ghostty = {
    enable = true;
    # TODO: Enable systemd service when it I've my updated my nixpkgs flake.
    # systemd = true;
    enableZshIntegration = true;
    installVimSyntax = true;
    settings = {
      window-decoration = false;
      shell-integration-features = "no-cursor";
      cursor-style = "block";
      cursor-style-blink = false;
      resize-overlay = "never";
      font-family = "FantasqueSansM Nerd Font Mono";
      # font-family-bold = "FantasqueSansM Nerd Font Mono Bold";
      # font-family-italic = "FantasqueSansM Nerd Font Mono Italic";
      # font-family-bold-italic = "FantasqueSansM Nerd Font Mono Bold Italic";
      font-size = "12.2";
      window-padding-x = "0,0";
      window-padding-y = "0,0";
      window-height = "30";
      window-width = "90";
      mouse-hide-while-typing = true;
      confirm-close-surface = false;
      clipboard-paste-protection = false;
      # window-inherit-working-directory = true;
      # quick-terminal-screen = "main";
      # keybind = "ctrl+f=toggle_quick_terminal";
      term = "xterm-256color";
      theme = "dracula";

      keybind = [
        "unconsumed:ctrl+shift+j=ignore"
        "ctrl+f=write_scrollback_file:copy"
        # "ctrl+f=write_scrollback_file:paste"
      ];
    };

    themes.dracula = {
      background = "1e1f29";
      foreground = "f8f8f2";
      selection-background = "44475a";
      selection-foreground = "f8f8f2";
      # cursor-color = "ff79c6";
      cursor-color = "bbbbbb";
      cursor-text = "282a36";
      palette = [
        "0=#21222c"
        "1=#ff5555"
        "2=#50fa7b"
        "3=#f1fa8c"
        "4=#bd93f9"
        "5=#ff79c6"
        "6=#8be9fd"
        "7=#f8f8f2"
        # "8=#6272a4"
        "8=#555555"
        "9=#ff6e6e"
        "10=#69ff94"
        "11=#ffffa5"
        "12=#d6acff"
        "13=#ff92df"
        "14=#a4ffff"
        "15=#ffffff"
      ];
    };
  };
}
