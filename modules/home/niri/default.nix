{ lib, pkgs, inputs, config, hostName, ... }:
let
  wallpaper = pkgs.fetchurl {
    url = "https://immich.clawsiecats.lol/api/assets/75f7fcc0-0465-42d6-8166-d98e5740bc2f/original?key=Qzi8AiA3FeSAJHXANoLZ2odUs5_2LxA5pfmb3Cr9-xfnBzZCI8UeZodZdr5TfFL0uJU";
    sha256 = "sha256-WeZxd4Ic4OdFHTCZO8UdMGXg/2GNTya28JdVa3+gvQQ=";
  };
in
{
  home.packages = with pkgs; [
    niri
    # Use Hyprland ecosystem tools instead of Sway equivalents
    hyprlock      # Instead of swaylock
    hyprpaper     # Instead of swaybg  
    hypridle      # Instead of swayidle
    hyprpicker    # Color picker
    hyprshot      # Screenshot tool
    hyprcursor    # Cursor theme tool
    wlsunset      # Blue light filter (hyprsunset doesn't work with niri)
    # wl-clipboard  # Already provided by wl-clipboard-rs in main config
    grim
    slurp
    wdisplays
    wlopm
  ];

  # Use theme module's cursor, just override hyprcursor
  home.pointerCursor.hyprcursor = {
    enable = true;
    size = 27;
  };

  # Create niri config file manually since home-manager niri module might not be fully available
  xdg.configFile."niri/config.kdl".text = ''
    // Niri configuration equivalent to Hyprland setup
    
    input {
        keyboard {
            xkb {
                layout "us"
            }
            repeat-delay 600
            repeat-rate 25
        }
        
        touchpad {
            tap
            dwt
            natural-scroll
            accel-speed 0.2
            accel-profile "adaptive"
            tap-button-map "left-right-middle"
            scroll-method "two-finger"
            click-method "button-areas"
        }
        
        mouse {
            accel-speed 0.0
            accel-profile "flat"
        }
        
        focus-follows-mouse max-scroll-amount="0%"
    }

    output "eDP-1" {
        mode "1920x1080@60"
        position x=0 y=0
        scale 1.0
        transform "normal"
    }

    output "HDMI-A-1" {
        off
    }

    output "HDMI-A-2" {
        mode "3840x2160@60"
        position x=0 y=2080
        scale 2.666667
        transform "270"
    }

    layout {
        gaps 5
        center-focused-column "never"
        
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        
        default-column-width { proportion 0.5; }
        
        focus-ring {
            off
        }
        
        border {
            width 2
            active-color "#1e7bb8"
            inactive-color "#1a1a1a"
        }
    }
    
    // Workspace definitions (niri doesn't support monitor assignments like Hyprland)
    workspace "1" {
        open-on-output "eDP-1"
    }
    
    workspace "2" {
        open-on-output "HDMI-A-1"
    }
    
    workspace "10" {
        open-on-output "HDMI-A-2"
    }

    prefer-no-csd

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    animations {
        slowdown 1.0
        window-open {
            duration-ms 150
            curve "ease-out-expo"
        }
        window-close {
            duration-ms 150
            curve "ease-out-expo"
        }
        horizontal-view-movement {
            duration-ms 200
            curve "ease-out-expo"
        }
        workspace-switch {
            duration-ms 200
            curve "ease-out-expo"
        }
        window-movement {
            duration-ms 200
            curve "ease-out-expo"
        }
        window-resize {
            duration-ms 200
            curve "ease-out-expo"
        }
    }

    window-rule {
        match app-id="^org\\.gnome\\.Nautilus$"
        default-column-width { fixed 800; }
    }

    window-rule {
        match title="^(Volume Control)$"
        default-column-width { fixed 800; }
        open-floating true
    }

    window-rule {
        match title="^(Picture-in-Picture)$"
        open-floating true
    }

    window-rule {
        match app-id="^polkit"
        open-floating true
    }

    window-rule {
        match app-id="^fuzzel$"
        open-floating true
    }

    window-rule {
        match app-id="^nwg-look$"
        open-floating true
    }

    window-rule {
        match app-id="^pavucontrol$"
        open-floating true
    }

    window-rule {
        match app-id="^keepassxc$"
        open-floating true
    }

    window-rule {
        match app-id="^org\\\\.gnome\\\\.Settings$"
        open-floating true
    }

    window-rule {
        match app-id="^file-roller$"
        open-floating true
    }

    window-rule {
        match app-id="^Pcmanfm$"
        open-floating true
    }

    window-rule {
        match app-id="^obs$"
        open-floating true
    }

    window-rule {
        match app-id="^wdisplays$"
        open-floating true
    }

    window-rule {
        match app-id="^zathura$"
        open-floating true
    }

    window-rule {
        match app-id="^zoom$"
        open-floating true
    }

    window-rule {
        match app-id="^Lxappearance$"
        open-floating true
    }

    window-rule {
        match app-id="^ncmpcpp$"
        open-floating true
    }

    window-rule {
        match app-id="^viewnior$"
        open-floating true
    }

    window-rule {
        match app-id="^gucharmap$"
        open-floating true
    }

    window-rule {
        match app-id="^gnome-font$"
        open-floating true
    }

    window-rule {
        match title="^(Media viewer)$"
        open-floating true
    }

    window-rule {
        match title="^(Firefox — Sharing Indicator)$"
        open-floating true
    }

    window-rule {
        match title="^(GLava)$"
        open-floating true
    }

    spawn-at-startup "swaync"
    spawn-at-startup "waybar-launch"
    spawn-at-startup "hyprpaper"
    spawn-at-startup "hypridle"
    spawn-at-startup "wlsunset" "-t" "3600"
    spawn-at-startup "xhost" "+local:"
    spawn-at-startup "lxqt-policykit-agent"
    spawn-at-startup "sh" "-c" "__NV_PRIME_RENDER_OFFLOAD=0 swayosd-server"

    environment {
        XDG_CURRENT_DESKTOP "niri"
        XDG_SESSION_DESKTOP "niri" 
        XDG_SESSION_TYPE "wayland"
        QT_FONT_DPI "74"
        SAL_USE_VCLPLUGIN "qt5"
        QT_SCALE_FACTOR "1"
        SAL_FORCEDPI "70"
        MOZ_USE_XINPUT2 "1"
        ${lib.optionalString (hostName == "mishy") ''
        LIBVA_DRIVER_NAME "nvidia"
        GBM_BACKEND "nvidia-drm"
        __GLX_VENDOR_LIBRARY_NAME "nvidia"
        WLR_NO_HARDWARE_CURSORS "1"
        WLR_DRM_NO_ATOMIC "1"
        ''}
    }

    // Cursor handled by home.pointerCursor in other modules

    binds {
        // Applications
        Mod+B { spawn "zen-beta"; }
        Mod+Q { spawn "${if pkgs.stdenv.hostPlatform.isAarch64 then "LIBGL_ALWAYS_SOFTWARE=1 " else ""}ghostty"; }
        Mod+C { close-window; }
        Mod+Ctrl+C { spawn "sh" "-c" "kill -9 $(niri msg focused-window | jq -r '.pid // empty')"; }
        Mod+Ctrl+Escape { quit; }
        Mod+E { spawn "nemo"; }
        Mod+V { toggle-window-floating; }

        // Focus movement (vi-like)
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+K { focus-window-up; }
        Mod+J { focus-window-down; }

        // Move windows
        Mod+Ctrl+H { move-column-left; }
        Mod+Ctrl+L { move-column-right; }
        Mod+Ctrl+K { move-window-up; }
        Mod+Ctrl+J { move-window-down; }

        // Workspaces
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+0 { focus-workspace 10; }
        
        // F-key workspaces (11-22)
        Mod+F1 { focus-workspace 11; }
        Mod+F2 { focus-workspace 12; }
        Mod+F3 { focus-workspace 13; }
        Mod+F4 { focus-workspace 14; }
        Mod+F5 { focus-workspace 15; }
        Mod+F6 { focus-workspace 16; }
        Mod+F7 { focus-workspace 17; }
        Mod+F8 { focus-workspace 18; }
        Mod+F9 { focus-workspace 19; }
        Mod+F10 { focus-workspace 20; }
        Mod+F11 { focus-workspace 21; }
        Mod+F12 { focus-workspace 22; }

        // Move to workspace
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }
        Mod+Shift+0 { move-column-to-workspace 10; }
        
        // Move to F-key workspaces (11-22)
        Mod+Shift+F1 { move-column-to-workspace 11; }
        Mod+Shift+F2 { move-column-to-workspace 12; }
        Mod+Shift+F3 { move-column-to-workspace 13; }
        Mod+Shift+F4 { move-column-to-workspace 14; }
        Mod+Shift+F5 { move-column-to-workspace 15; }
        Mod+Shift+F6 { move-column-to-workspace 16; }
        Mod+Shift+F7 { move-column-to-workspace 17; }
        Mod+Shift+F8 { move-column-to-workspace 18; }
        Mod+Shift+F9 { move-column-to-workspace 19; }
        Mod+Shift+F10 { move-column-to-workspace 20; }
        Mod+Shift+F11 { move-column-to-workspace 21; }
        Mod+Shift+F12 { move-column-to-workspace 22; }

        // Scroll through workspaces
        Mod+Left { focus-workspace-down; }
        Mod+Right { focus-workspace-up; }
        Mod+Shift+Left { move-column-to-workspace-down; }
        Mod+Shift+Right { move-column-to-workspace-up; }
        
        // Last workspace
        Mod+grave { focus-workspace-previous; }
        
        // Special workspace equivalents
        Mod+Return { focus-workspace "empty"; }
        Mod+T { move-column-to-workspace-down; }

        // Launchers (force Wayland mode by unsetting DISPLAY)
        Ctrl+Semicolon { spawn "sh" "-c" "unset DISPLAY && ROFI_WIDTH=700 ROFI_LINES=10 rofi -show combi"; }
        Ctrl+Apostrophe { spawn "sh" "-c" "unset DISPLAY && rofi-bluetooth"; }
        Ctrl+Shift+Apostrophe { spawn "sh" "-c" "unset DISPLAY && ROFI_WIDTH=700 ROFI_LINES=10 rofi -show filebrowser"; }
        Ctrl+Shift+Semicolon { spawn "sh" "-c" "unset DISPLAY && ROFI_WIDTH=700 ROFI_LINES=10 rofi -show run"; }
        Ctrl+M { spawn "sh" "-c" "unset DISPLAY && ROFI_WIDTH=850 rofi-pulse-select sink"; }
        Ctrl+Shift+M { spawn "sh" "-c" "unset DISPLAY && ROFI_WIDTH=950 rofi-pulse-select source"; }
        Ctrl+H { spawn "sh" "-c" "unset DISPLAY && rofimoji"; }
        Ctrl+Backslash { spawn "sh" "-c" "unset DISPLAY && rofi -show calc -no-show-match -no-sort -automatic-save-to-history -calc-command-history -calc-command \"echo -n '{result}' | wl-copy\""; }
        
        // Fullscreen
        F11 { fullscreen-window; }

        // Screenshots
        Print { screenshot-screen; }
        Shift+Print { screenshot-window; }
        Mod+Print { screenshot; }

        // Notifications
        Ctrl+Shift+Q { spawn "swaync-client" "-t"; }
        Ctrl+Shift+X { spawn "swaync-client" "--hide-latest"; }

        // Audio
        XF86AudioRaiseVolume { spawn "swayosd-client" "--output-volume" "+2"; }
        XF86AudioLowerVolume { spawn "swayosd-client" "--output-volume" "-2"; }
        XF86AudioMute { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
        F7 { spawn "swayosd-client" "--output-volume" "+2"; }
        F6 { spawn "swayosd-client" "--output-volume" "-2"; }
        
        // Per-app volume controls
        Ctrl+XF86AudioRaiseVolume { spawn "sh" "-c" "wpctl set-volume -l 1.0 -p $(niri msg focused-window | jq -r '.pid // empty') 2%+; notify-send -u low -t 1000 -r 10 \"2%+ Volume for $(niri msg focused-window | jq -r '.title // \"Unknown\"')\""; }
        Ctrl+XF86AudioLowerVolume { spawn "sh" "-c" "wpctl set-volume -l 1.0 -p $(niri msg focused-window | jq -r '.pid // empty') 2%-; notify-send -u low -t 1000 -r 10 \"2%- Volume for $(niri msg focused-window | jq -r '.title // \"Unknown\"')\""; }
        Ctrl+XF86AudioMute { spawn "sh" "-c" "wpctl set-mute -p $(niri msg focused-window | jq -r '.pid // empty') toggle; notify-send -u low -t 1000 -r 10 \"Toggle Mute for $(niri msg focused-window | jq -r '.title // \"Unknown\"')\""; }
        Ctrl+F7 { spawn "sh" "-c" "wpctl set-volume -l 1.0 -p $(niri msg focused-window | jq -r '.pid // empty') 2%+; notify-send -u low -t 1000 -r 10 \"2%+ Volume for $(niri msg focused-window | jq -r '.title // \"Unknown\"')\""; }
        Ctrl+F6 { spawn "sh" "-c" "wpctl set-volume -l 1.0 -p $(niri msg focused-window | jq -r '.pid // empty') 2%-; notify-send -u low -t 1000 -r 10 \"2%- Volume for $(niri msg focused-window | jq -r '.title // \"Unknown\"')\""; }
        Ctrl+F10 { spawn "sh" "-c" "wpctl set-mute -p $(niri msg focused-window | jq -r '.pid // empty') toggle; notify-send -u low -t 1000 -r 10 \"Toggle Mute for $(niri msg focused-window | jq -r '.title // \"Unknown\"')\""; }

        // Input volume controls  
        Shift+XF86AudioRaiseVolume { spawn "swayosd-client" "--input-volume" "+5"; }
        Shift+XF86AudioLowerVolume { spawn "swayosd-client" "--input-volume" "-5"; }
        Shift+XF86AudioMute { spawn "swayosd-client" "--input-volume" "mute-toggle"; }
        Shift+F7 { spawn "swayosd-client" "--input-volume" "+5"; }
        Shift+F6 { spawn "swayosd-client" "--input-volume" "-5"; }
        
        // Brightness
        XF86MonBrightnessUp { spawn "swayosd-client" "--device" "intel_backlight" "--brightness" "raise"; }
        XF86MonBrightnessDown { spawn "swayosd-client" "--device" "intel_backlight" "--brightness" "lower"; }
        Shift+XF86MonBrightnessUp { spawn "swayosd-client" "--device" "asus::screenpad" "--brightness" "raise"; }
        Shift+XF86MonBrightnessDown { spawn "swayosd-client" "--device" "asus::screenpad" "--brightness" "lower"; }

        // Media control
        XF86AudioPlay { spawn "swayosd-client" "--playerctl=play"; }
        XF86AudioPause { spawn "swayosd-client" "--playerctl=pause"; }
        XF86AudioNext { spawn "playerctl" "next"; }
        XF86AudioPrev { spawn "playerctl" "previous"; }
        F8 { spawn "playerctl" "previous"; }
        F9 { spawn "playerctl" "next"; }
        F10 { spawn "swayosd-client" "--playerctl=play-pause"; }

        // Window management (group management from Hyprland - niri doesn't have groups but these are window navigation)
        Mod+Tab { focus-window-down-or-column-right; }
        Mod+Shift+Tab { focus-window-up-or-column-left; }
        Alt+Tab { focus-window-down-or-column-right; }
        
        // Group management keybindings (niri doesn't support groups, but keeping window navigation)
        Mod+G { focus-window-down-or-column-right; }
        Ctrl+1 { focus-workspace 1; }
        Ctrl+2 { focus-workspace 2; }
        Ctrl+3 { focus-workspace 3; }
        Ctrl+4 { focus-workspace 4; }
        Ctrl+5 { focus-workspace 5; }
        Ctrl+6 { focus-workspace 6; }
        Ctrl+7 { focus-workspace 7; }
        Ctrl+8 { focus-workspace 8; }
        Ctrl+9 { focus-workspace 9; }
        Ctrl+0 { focus-workspace 10; }
        
        // Additional window management (niri equivalents)
        Mod+P { center-column; }
        Mod+S { consume-or-expel-window-left; }

        // Layout management
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        
        // Resize functionality - use column width switching and window movement instead
        Mod+Shift+R { switch-preset-column-width; }
        
        // Mouse bindings for window management
        Mod+WheelScrollDown { focus-workspace-down; }
        Mod+WheelScrollUp { focus-workspace-up; }
        Mod+Shift+WheelScrollDown { move-column-to-workspace-down; }
        Mod+Shift+WheelScrollUp { move-column-to-workspace-up; }
        
        // Caps lock indicator (removed - invalid syntax in niri)
        
        // Monitor management keybindings
        Mod+Ctrl+Shift+1 { spawn "niri" "msg" "action" "move-workspace-to-monitor-left"; }
        Mod+Ctrl+Shift+2 { spawn "niri" "msg" "action" "move-workspace-to-monitor-right"; }
        Mod+Ctrl+Shift+0 { spawn "niri" "msg" "action" "move-workspace-to-monitor-down"; }
        
        // Mouse button bindings removed - niri uses different mouse binding syntax
    }
  '';

  # Use existing hyprpaper and hypridle services from hyprland module
  # These will be configured to work with niri as well
  
  # The hyprlock and hypridle configs are already set up in the hyprland module
  # and will work with niri since they're independent of the compositor
}