{ pkgs, inputs, config, ... }:
let
  wallpaper = pkgs.fetchurl {
    url = "https://i.imgur.com/gtGew3r.jpg";
    sha256 = "0kjkj73szx2ahdh9kxyzy2z4alh2xz4z47fzbc9ns6mcxjwqsr1s";
  };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    # enableNvidiaPatches = true;
    # xwayland.enable = false;
    systemd = {
      enable = true;
      variables = ["-all"];
    };
    extraConfig = builtins.readFile ../chezmoi/dot_config/hypr/hyprland.conf;
  };

  home.packages = with pkgs; [
    xdg-desktop-portal-hyprland
    hypridle
    hyprlock
    hyprpaper
    hyprpicker
    hyprcursor
    hyprshot
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
  ];

  services = {
    hyprpaper = {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        # splash_offset = 90;
        preload = [
          (builtins.toString wallpaper)
        ];
        wallpaper = [
          "eDP-1,${builtins.toString wallpaper}"
          "HDMI-A-1,${builtins.toString wallpaper}"
          "HDMI-A-2,${builtins.toString wallpaper}"
        ];
      };
    };
    hypridle = {
      enable = true;
      settings = {
        general = {
          before_sleep_cmd = "pidof hyprlock || hyprlock --immediate";
          ignore_dbus_inhibit = false;
        };
        listener = [
          {
            timeout = 1800;
            on-timeout = "hyprlock";
          }
          {
            timeout = 3600;
            on-timeout = "hyprctl dispatch dpms off; pkill -f wl-gammarelay-rs";
            on-resume = "hyprctl reload; hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };

  home.file = {
    hyprland = {
      source =  ../chezmoi/dot_config/hypr/hyprland;
      target = "${config.home.homeDirectory}/.config/hypr/hyprland";
    };
    # hypridle = {
    #   source =  ../chezmoi/dot_config/hypr/hypridle.conf;
    #   target = "${config.home.homeDirectory}/.config/hypr/hypridle.conf";
    # };
    hyprlock = {
      source =  ../chezmoi/dot_config/hypr/hyprlock.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hyprlock.conf";
    };
  };
}
