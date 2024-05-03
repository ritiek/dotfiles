{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rofi-bluetooth
  ];
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    # plugins = with pkgs; [
    #   rofi-bluetooth
    # ];
    # FIXME: a very ugly hack to override existing theme, improve this.
    theme = ''Arc-Dark"

entry {
  cursor: pointer;
}

element {
  orientation: horizontal;
  children: [ element-text, element-icon ];
  spacing: 5px;
}

element-icon {
  size: 1.25em;
}
//'';
    cycle = true;
    extraConfig = {
      modes = [
        "combi"
        "window"
        "drun"
        "ssh"
        "filebrowser"
      ];
      combi-modes = [
        "window"
        "drun"
        "ssh"
      ];
      font = "FantasqueSansM Nerd Font Mono 14";
      show-icons = true;
      terminal = "alacritty";
    };
  };
}
