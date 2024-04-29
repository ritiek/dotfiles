{ pkgs, config, ... }:
{
  home.file.hyprland = {
    source = config.lib.file.mkOutOfStoreSymlink ./chezmoi/dot_config/hypr/hyprland;
    target = "${config.home.homeDirectory}/.config/hypr/hyprland";
  };
  wayland.windowManager.hyprland = {
    enable = true;
    enableNvidiaPatches = true;
    # xwayland.enable = false;
    systemd.enable = true;
    extraConfig = builtins.readFile /etc/nixos/chezmoi/dot_config/hypr/hyprland.conf;
  };
}
