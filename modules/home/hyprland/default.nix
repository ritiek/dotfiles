{ lib, pkgs, inputs, config, ... }:
let
  wallpaper = pkgs.fetchurl {
    # url = "https://i.imgur.com/gtGew3r.jpg";
    # sha256 = "0kjkj73szx2ahdh9kxyzy2z4alh2xz4z47fzbc9ns6mcxjwqsr1s";

    # url = "https://i.imgur.com/iFHxPpc.png";
    # sha256 = "sha256-WeZxd4Ic4OdFHTCZO8UdMGXg/2GNTya28JdVa3+gvQQ=";
    # url = "https://filebrowser.clawsiecats.omg.lol/api/public/dl?path=/&hash=_fTtyPc1heMt5Ypxi68MZQ&inline=true";
    # sha256 = "sha256-WeZxd4Ic4OdFHTCZO8UdMGXg/2GNTya28JdVa3+gvQQ=";
    url = "https://immich.clawsiecats.omg.lol/api/assets/75f7fcc0-0465-42d6-8166-d98e5740bc2f/original?key=Qzi8AiA3FeSAJHXANoLZ2odUs5_2LxA5pfmb3Cr9-xfnBzZCI8UeZodZdr5TfFL0uJU";
    sha256 = "sha256-WeZxd4Ic4OdFHTCZO8UdMGXg/2GNTya28JdVa3+gvQQ=";
  };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
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
    hyprsunset
    # hyprpolkitagent
    # waypaper
  ];

  home.pointerCursor = {
    name = "rose-pine-hyprcursor";
    # package = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
    package = pkgs.rose-pine-cursor;
    hyprcursor = {
      enable = true;
      size = 27;
    };
  };

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
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on && (pidof swayosd-server || swayosd-server)";
          }
        ];
      };
    };
  };

  programs = {
    # mpvpaper = {
    #   enable = true;
    #   pauseList = ''
    #     firefox
    #   '';
    #   stopList = ''
    #     firefox
    #   '';
    # };
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
    if [ -e /run/user/1000/hypr/*/.socket.sock ]; then
      HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/ls -td /run/user/$UID/hypr/*/ | ${pkgs.coreutils}/bin/head -n 1)") \
      ${pkgs.hyprland}/bin/hyprctl reload config-only
    else
      ${pkgs.coreutils}/bin/echo "Hyprland socket file does not exist, skipping reload"
    fi
  '';
}
