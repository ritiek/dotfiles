{ lib, pkgs, inputs, config, hostName, ... }:
let
  wallpaper = pkgs.fetchurl {
    # url = "https://i.imgur.com/gtGew3r.jpg";
    # sha256 = "0kjkj73szx2ahdh9kxyzy2z4alh2xz4z47fzbc9ns6mcxjwqsr1s";

    # url = "https://i.imgur.com/iFHxPpc.png";
    # sha256 = "sha256-WeZxd4Ic4OdFHTCZO8UdMGXg/2GNTya28JdVa3+gvQQ=";
    # url = "https://filebrowser.clawsiecats.lol/api/public/dl?path=/&hash=_fTtyPc1heMt5Ypxi68MZQ&inline=true";
    # sha256 = "sha256-WeZxd4Ic4OdFHTCZO8UdMGXg/2GNTya28JdVa3+gvQQ=";
    url = "https://immich.clawsiecats.lol/api/assets/f7c51f4f-16b5-4e94-951b-bb2286059e7d/original?slug=sunrise";
    sha256 = "sha256-5MVdhQSPWTAGwa990Edqjyh4HcwfuPlQ67KvrDh6eew=";
  };
in
{
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
    # package = inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
            on-resume = "hyprctl dispatch dpms on && (pidof swayosd-server || __NV_PRIME_RENDER_OFFLOAD=0 swayosd-server)";
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
    # hyprland = {
    #   source =  ./hypr/hyprland;
    #   target = "${config.home.homeDirectory}/.config/hypr/hyprland";
    # };
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

  wayland.windowManager.hyprland = {
    enable = true;
    # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # enableNvidiaPatches = true;
    xwayland.enable = true;
    plugins = [
      # inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    systemd = {
      enable = true;
      variables = ["-all"];
    };
    
    settings = {
      # Environment variables (from env.conf)
      env = [
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "QT_FONT_DPI,74"
        "SAL_USE_VCLPLUGIN,qt5"
        "QT_SCALE_FACTOR,1"
        "SAL_FORCEDPI,70"
        "MOZ_USE_XINPUT2,1"
      ] ++ pkgs.lib.optionals (hostName == "mishy") [
        "LIBVA_DRIVER_NAME,nvidia"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "WLR_NO_HARDWARE_CURSORS,1"
        "WLR_DRM_NO_ATOMIC,1"
        "WLR_DRM_DEVICES,/dev/dri/card0:/dev/dri/card1"
      ];

      # Variables (from var.conf)
      "$mainMod" = "SUPER";
      "$primaryMonitor" = "eDP-1";
      "$primaryMonitorBlk" = "intel_backlight";
      "$screenPadMonitor" = "HDMI-A-2";
      "$screenPadMonitorBlk" = "asus::screenpad";
      "$externalMonitor" = "HDMI-A-1";

      # Volume commands
      "$outputVolumeUpCommand" = "swayosd-client --output-volume +2";
      "$outputVolumeDownCommand" = "swayosd-client --output-volume -2";
      "$outputVolumeMuteCommand" = "swayosd-client --output-volume mute-toggle";
      "$appOutputVolumeUpCommand" = "wpctl set-volume -l 1.0 -p $(hyprctl activewindow -j | jq -r '.pid') 2%+; notify-send -u low -t 1000 -r 10 \"2%+ Volume for $(hyprctl activewindow -j | jq -r '.title')\"";
      "$appOutputVolumeDownCommand" = "wpctl set-volume -l 1.0 -p $(hyprctl activewindow -j | jq -r '.pid') 2%-; notify-send -u low -t 1000 -r 10 \"2%- Mute for $(hyprctl activewindow -j | jq -r '.title')\"";
      "$appOutputVolumeMuteCommand" = "wpctl set-mute -p $(hyprctl activewindow -j | jq -r '.pid') toggle; notify-send -u low -t 1000 -r 10 \"Toggle Mute for $(hyprctl activewindow -j | jq -r '.title')\"";
      "$inputVolumeUpCommand" = "swayosd-client --input-volume +5";
      "$inputVolumeDownCommand" = "swayosd-client --input-volume -5";
      "$inputVolumeMuteCommand" = "swayosd-client --input-volume mute-toggle";

      # Monitor configuration (from monitor.conf)
      monitor = [
        "$primaryMonitor, preferred, 0x0, 1.0, bitdepth, 8"
        "$screenPadMonitor, highres, 0x2080, 2.666667, transform, 3, bitdepth, 8"
        "$externalMonitor, preferred, 0x0, 1.0, mirror, eDP-1, bitdepth, 8"
      ];

      # Exec commands (from exec.conf)
      exec-once = [
        "swaync"
        "waybar"
        "hyprpaper"
        "hypridle"
        "xhost +local:"
        "lxqt-policykit-agent"
        "hyprsunset -t 3600"
      ];
      
      exec = [
        "__NV_PRIME_RENDER_OFFLOAD=0 swayosd-server"
      ];

      # Workspace configuration (from rule.conf)
      workspace = [
        "special, gapsin:50, gapsout:100"
        "1, monitor:$primaryMonitor"
        "2, monitor:$externalMonitor"
        "3, monitor:$primaryMonitor"
        "4, monitor:$externalMonitor"
        "5, monitor:$primaryMonitor"
        "6, monitor:$externalMonitor"
        "7, monitor:$primaryMonitor"
        "8, monitor:$externalMonitor"
        "9, monitor:$primaryMonitor"
        "10, monitor:$screenPadMonitor"
      ];

      # Window rules (from rule.conf)
      windowrule = [
        "noborder, onworkspace:w[t1]"
        "float, title:^(Bitwarden)$, class:^(Google-chrome)$"
        "float, class:^(Rofi)$"
        "float, class:polkit"
        "float, class:file_progress"
        "float, class:confirm"
        "float, class:dialog"
        "float, class:download"
        "float, class:notification"
        "float, class:error"
        "float, class:splash"
        "float, class:confirmreset"
        "float, title:Open File"
        "float, title:branchdialog"
        "float, class:zoom"
        "float, class:Lxappearance"
        "float, class:nwg-look"
        "float, class:ncmpcpp"
        "float, class:viewnior"
        "tile, class:pavucontrol"
        "float, class:gucharmap"
        "float, class:gnome-font"
        "float, class:org.gnome.Settings"
        "float, class:file-roller"
        "float, class:Pcmanfm"
        "float, class:obs"
        "float, class:wdisplays"
        "float, class:zathura"
        "float, class:*.exe"
        "fullscreen, class:wlogout"
        "float, title:wlogout"
        "fullscreen, title:wlogout"
        "float, class:keepassxc"
        "idleinhibit focus, class:mpv"
        "idleinhibit fullscreen, class:firefox"
        "idleinhibit fullscreen, class:librewolf"
        "idleinhibit fullscreen, class:zen"
        "float, title:^(Media viewer)$"
        "float, title:^(Volume Control)$"
        "float, title:^(Picture-in-Picture)$"
        "float, title:^(Firefox — Sharing Indicator)$"
        "move 0 0, title:^(Firefox — Sharing Indicator)$"
        "size 800 600, title:^(Volume Control)$"
        "move 75 44%, title:^(Volume Control)$"
        "tile, 0.85, class:^(ballistica.*|bombsquad|.bombsquad-wrapped)$"
        "float, title:^(GLava)$"
        "size 100% 70, title:^(GLava)$"
        "move 0 100%-110, title:^(GLava)$"
        "noblur, title:^(GLava)$"
        "noborder, title:^(GLava)$"
        "nofocus, title:^(GLava)$"
      ];

      # Key bindings (from bind.conf)
      bind = [
        # Application bindings
        "$mainMod, B, exec, zen-beta"
        # Workaround for ghostty complaining "Unable to create gl context" on RPi400.
        "$mainMod, Q, exec, ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isAarch64 "LIBGL_ALWAYS_SOFTWARE=1 "}ghostty"
        # "$mainMod, Q, exec, ghostty"
        "$mainMod, C, killactive,"
        "$mainMod CTRL, C, exec, kill -9 $(hyprctl activewindow -j | jq -r '.pid')"
        "$mainMod CTRL, escape, exit,"
        "$mainMod, E, exec, nemo"
        "$mainMod, V, togglefloating,"
        "$mainMod, V, resizeactive, exact 900 700"
        
        # Window management
        "$mainMod, TAB, pin,"
        "$mainMod, P, pseudo,"
        "$mainMod, S, togglesplit,"
        
        # Rofi launchers
        "CTRL, code:47, exec, ROFI_WIDTH=700 ROFI_LINES=10 rofi -show combi"
        "CTRL, code:48, exec, rofi-bluetooth"
        "CTRL SHIFT, code:48, exec, ROFI_WIDTH=700 ROFI_LINES=10 rofi -show filebrowser"
        "CTRL SHIFT, code:47, exec, ROFI_WIDTH=700 ROFI_LINES=10 rofi -show run"
        "CTRL, M, exec, ROFI_WIDTH=850 rofi-pulse-select sink"
        "CTRL SHIFT, M, exec, ROFI_WIDTH=950 rofi-pulse-select source"
        "CTRL, code:35, exec, rofimoji"
        "CTRL, code:51, exec, rofi -show calc -no-show-match -no-sort -automatic-save-to-history -calc-command-history -calc-command \"echo -n '{result}' | wl-copy\""
        
        # Focus movement
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"
        
        # Workspace switching
        "$mainMod, left, workspace, -1"
        "$mainMod, right, workspace, +1"
        "$mainMod SHIFT, h, workspace, -1"
        "$mainMod SHIFT, l, workspace, +1"
        
        # Workspace bindings (1-10)
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        
        # F-key workspace bindings (F1-F12)
        "$mainMod, F1, workspace, 11"
        "$mainMod, F2, workspace, 12"
        "$mainMod, F3, workspace, 13"
        "$mainMod, F4, workspace, 14"
        "$mainMod, F5, workspace, 15"
        "$mainMod, F6, workspace, 16"
        "$mainMod, F7, workspace, 17"
        "$mainMod, F8, workspace, 18"
        "$mainMod, F9, workspace, 19"
        "$mainMod, F10, workspace, 20"
        "$mainMod, F11, workspace, 21"
        "$mainMod, F12, workspace, 22"
        
        # Other workspace operations
        "$mainMod, grave, focusurgentorlast"
        
        # Group management
        "$mainMod, G, togglegroup"
        "$mainMod SHIFT, G, lockgroups, toggle"
        "$mainMod, Tab, changegroupactive, f"
        "$mainMod SHIFT, Tab, changegroupactive, b"
        "CTRL, 1, changegroupactive, 1"
        "CTRL, 2, changegroupactive, 2"
        "CTRL, 3, changegroupactive, 3"
        "CTRL, 4, changegroupactive, 4"
        "CTRL, 5, changegroupactive, 5"
        "CTRL, 6, changegroupactive, 6"
        "CTRL, 7, changegroupactive, 7"
        "CTRL, 8, changegroupactive, 8"
        "CTRL, 9, changegroupactive, 9"
        "CTRL, 10, changegroupactive, 10"
        
        # Alt-tab
        "ALT, Tab, cyclenext,"
        "ALT, Tab, bringactivetotop,"
        
        # Move windows to workspace
        "$mainMod SHIFT, left, movetoworkspace, -1"
        "$mainMod SHIFT, right, movetoworkspace, +1"
        "$mainMod CTRL SHIFT, h, movetoworkspace, -1"
        "$mainMod CTRL SHIFT, l, movetoworkspace, +1"
        
        # Move to numbered workspaces
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        
        # Move to F-key workspaces
        "$mainMod SHIFT, F1, movetoworkspace, 11"
        "$mainMod SHIFT, F2, movetoworkspace, 12"
        "$mainMod SHIFT, F3, movetoworkspace, 13"
        "$mainMod SHIFT, F4, movetoworkspace, 14"
        "$mainMod SHIFT, F5, movetoworkspace, 15"
        "$mainMod SHIFT, F6, movetoworkspace, 16"
        "$mainMod SHIFT, F7, movetoworkspace, 17"
        "$mainMod SHIFT, F8, movetoworkspace, 18"
        "$mainMod SHIFT, F9, movetoworkspace, 19"
        "$mainMod SHIFT, F10, movetoworkspace, 20"
        "$mainMod SHIFT, F11, movetoworkspace, 21"
        "$mainMod SHIFT, F12, movetoworkspace, 22"
        
        # Special workspaces
        "$mainMod, Return, workspace, empty"
        "$mainMod, F, togglespecialworkspace"
        "$mainMod, W, movetoworkspace, special"
        "$mainMod, T, movetoworkspace, e+0"
        
        # Mouse workspace scrolling
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        
        # Monitor management
        "$mainMod CTRL SHIFT, 1, movecurrentworkspacetomonitor, eDP-1"
        "$mainMod CTRL SHIFT, 2, movecurrentworkspacetomonitor, HDMI-A-1"
        "$mainMod CTRL SHIFT, 0, movecurrentworkspacetomonitor, HDMI-A-2"
        
        # Move windows
        "$mainMod CTRL, H, movewindow, l"
        "$mainMod CTRL, L, movewindow, r"
        "$mainMod CTRL, K, movewindow, u"
        "$mainMod CTRL, J, movewindow, d"
        
        # Fullscreen
        ", F11, fullscreen"
        "CTRL, F11, fullscreenstate, 0 3"
        
        # Notifications
        "CTRL SHIFT, Q, exec, swaync-client -t"
        "CTRL SHIFT, X, exec, swaync-client --hide-latest"
        
        # Screenshots
        ", Print, exec, hyprshot --freeze --clipboard-only --mode region"
        "SHIFT, Print, exec, hyprshot --freeze --output-folder ~/Pictures/Screenshots --mode region -- imv-dir"
        "$mainMod, Print, exec, hyprshot --freeze --output-folder ~/Pictures/Screenshots --mode output -- imv-dir"
        "$mainMod SHIFT, Print, exec, hyprshot --freeze --clipboard-only --mode window"
        
        # Resize submap
        "ALT, R, submap, resize"
        
        # Caps lock indicator
        ", code:66, exec, sleep 0.12 && swayosd-client --caps-lock"
        
        # Media keys
        ", XF86AudioPlay, exec, swayosd-client --playerctl=play"
        ", XF86AudioPause, exec, swayosd-client --playerctl=pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", F8, exec, playerctl previous"
        ", F9, exec, playerctl next"
        ", F10, exec, swayosd-client --playerctl=play-pause"
      ];

      # Bindel (repeat bindings)
      bindel = [
        # Output volume
        ", XF86AudioRaiseVolume, exec, $outputVolumeUpCommand"
        ", XF86AudioLowerVolume, exec, $outputVolumeDownCommand"
        ", XF86AudioMute, exec, $outputVolumeMuteCommand"
        ", F7, exec, $outputVolumeUpCommand"
        ", F6, exec, $outputVolumeDownCommand"
        
        # Per-app volume
        "CTRL, XF86AudioRaiseVolume, exec, $appOutputVolumeUpCommand"
        "CTRL, XF86AudioLowerVolume, exec, $appOutputVolumeDownCommand"
        "CTRL, XF86AudioMute, exec, $appOutputVolumeMuteCommand"
        "CTRL, F7, exec, $appOutputVolumeUpCommand"
        "CTRL, F6, exec, $appOutputVolumeDownCommand"
        "CTRL, F10, exec, $appOutputVolumeMuteCommand"
        
        # Input volume
        "SHIFT, XF86AudioRaiseVolume, exec, $inputVolumeUpCommand"
        "SHIFT, XF86AudioLowerVolume, exec, $inputVolumeDownCommand"
        "SHIFT, XF86AudioMute, exec, $inputVolumeMuteCommand"
        "SHIFT, F7, exec, $inputVolumeUpCommand"
        "SHIFT, F6, exec, $inputVolumeDownCommand"
        
        # Brightness
        ", XF86MonBrightnessUp, exec, swayosd-client --device $primaryMonitorBlk --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --device $primaryMonitorBlk --brightness lower"
        "SHIFT, XF86MonBrightnessUp, exec, swayosd-client --device $screenPadMonitorBlk --brightness raise"
        "SHIFT, XF86MonBrightnessDown, exec, swayosd-client --device $screenPadMonitorBlk --brightness lower"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "ALT, mouse:272, resizewindow"
      ];

      # Resize submap
      submap = [
        "resize"
      ];

      input = {
        kb_layout = "us";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          scroll_factor = 0.2;
        };
        sensitivity = 0;
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgb(268bd2)";
        "col.inactive_border" = "rgb(1a1a1a)";
        no_border_on_floating = false;
        layout = "dwindle";
        allow_tearing = true;
      };

      decoration = {
        rounding = 5;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        blur = {
          enabled = true;
          size = 10;
          passes = 1;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          ignore_window = true;
          range = 4;
          offset = "2 2";
          render_power = 2;
          color = "0x66000000";
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        special_scale_factor = 0.9;
      };

      master = {
        # new_is_master = true;
      };

      gestures = {
        workspace_swipe = true;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        disable_autoreload = true;
        disable_splash_rendering = true;
        initial_workspace_tracking = 1;
      };

      device = {
        name = "logitech-g102-prodigy-gaming-mouse";
        sensitivity = -1.0;
      };
    };

    # Additional configuration for the resize submap
    extraConfig = ''
      submap = resize
      binde = , l, resizeactive, 30 0
      binde = , h, resizeactive, -30 0
      binde = , k, resizeactive, 0 -30
      binde = , j, resizeactive, 0 30
      binde = SHIFT, l, resizeactive, 90 0
      binde = SHIFT, h, resizeactive, -90 0
      binde = SHIFT, k, resizeactive, 0 -90
      binde = SHIFT, j, resizeactive, 0 90
      bind = , escape, submap, reset
      submap = reset
    '';
  };
}
