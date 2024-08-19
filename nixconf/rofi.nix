{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rofi-bluetooth
    # Use rofi for wayland instead of X11
    (rofi-pulse-select.override {
      rofi-unwrapped = rofi-wayland;
    })
  ];
  programs.rofi = {
    enable = true;
    # Doesn't work for some reason.
    # plugins = with pkgs; [
    #   rofi-bluetooth
    #   rofi-pulse-select
    # ];
    package = pkgs.rofi-wayland;
    theme = builtins.toFile "rofi-theme.rasi" ''
      /*******************************************************************************
       * ROUNDED THEME FOR ROFI
       * User                 : LR-Tech
       * Theme Repo           : https://github.com/lr-tech/rofi-themes-collection
       *******************************************************************************/

      * {
          bg0:    #212121F2;
          bg1:    #2A2A2A;
          bg2:    #3D3D3D80;
          bg3:    #616161F2;
          fg0:    #E6E6E6;
          fg1:    #FFFFFF;
          fg2:    #969696;
          fg3:    #3D3D3D;

          // font:   "Roboto 12";

          background-color:   transparent;
          text-color:         @fg0;

          margin:     0px;
          padding:    0px;
          spacing:    0px;
      }

      window {
          location:       center;
          width:          env(ROFI_WIDTH, 560);
          border-radius:  24px;

          background-color:   @bg0;
      }

      mainbox {
          padding:    12px;
      }

      inputbar {
          background-color:   @bg1;
          border-color:       @bg3;

          border:         2px;
          border-radius:  16px;

          padding:    8px 16px;
          spacing:    8px;
          children:   [ prompt, entry ];
      }

      prompt {
          text-color: @fg2;
      }

      entry {
          placeholder:        "Search";
          placeholder-color:  @fg3;
      }

      message {
          margin:             12px 0 0;
          border-radius:      16px;
          border-color:       @bg2;
          background-color:   @bg2;
      }

      textbox {
          padding:    8px 24px;
      }

      listview {
          background-color:   transparent;

          margin:     12px 0 0;
          lines:      env(ROFI_LINES, 8);
          columns:    1;

          fixed-height: true;
      }

      element {
          cursor:         pointer;
          padding:        8px 16px;
          spacing:        8px;
          border-radius:  16px;
      }

      element normal active {
          text-color: @bg3;
      }

      element alternate active {
          text-color: @bg3;
      }

      element selected normal, element selected active {
          background-color:   @bg3;
      }

      element-icon {
          size:           1em;
          vertical-align: 0.5;
      }

      element-text {
          text-color: inherit;
      }
    '';
    cycle = true;
    extraConfig = {
      modes = [
        "combi"
        "window"
        "drun"
	"run"
        "ssh"
        "filebrowser"
      ];
      combi-modes = [
        "window"
        "drun"
        "ssh"
      ];
      font = "Roboto 12";
      show-icons = true;
      terminal = "wezterm";
    };
  };
}
