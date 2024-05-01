{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    swayidle
  ];
  # home.file.swayidle = {
  #   source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/swayidle;
  #   target = "${config.home.homeDirectory}/.config/swayidle";
  # };
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 1800;
        command = "${pkgs.unstable.hyprlock}/bin/hyprlock";
      }
      {
        timeout = 3600;
        command = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
        resumeCommand = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      }
    ];
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.unstable.hyprlock}/bin/hyprlock";
      }
    ];
  };
}
