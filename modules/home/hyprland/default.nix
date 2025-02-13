{ lib, pkgs, inputs, config, ... }:
let
  wallpaper = pkgs.fetchurl {
    url = "https://i.imgur.com/gtGew3r.jpg";
    sha256 = "0kjkj73szx2ahdh9kxyzy2z4alh2xz4z47fzbc9ns6mcxjwqsr1s";
  };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    # enableNvidiaPatches = true;
    xwayland.enable = true;
    plugins = [
      # inputs.hyprgrass.packages.${pkgs.system}.default
    ];
    systemd = {
      enable = true;
      variables = ["-all"];
    };
    extraConfig = builtins.readFile ./hypr/hyprland.conf;
  };

  home.packages = with pkgs; [
    # xdg-desktop-portal-hyprland
    # xdg-desktop-portal-wlr
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
      source =  ./hypr/hyprland;
      target = "${config.home.homeDirectory}/.config/hypr/hyprland";
    };
    # hypridle = {
    #   source =  ./hypr/hypridle.conf;
    #   target = "${config.home.homeDirectory}/.config/hypr/hypridle.conf";
    # };
    hyprlock = {
      source =  ./hypr/hyprlock.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hyprlock.conf";
    };
  };

  # XXX: Shouldn't hyprland's NixOS module be handling auto-reload by itself?
  home.activation.reload-hyprland = lib.hm.dag.entryAfter ["writeBoundary"] ''
    HYPRLAND_INSTANCE_SIGNATURE=$(basename $(echo /run/user/1000/hypr/*)) \
      ${pkgs.hyprland}/bin/hyprctl reload config-only
  '';
}
