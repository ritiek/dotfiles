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
    # hyprcursor    # Cursor theme tool
    wlsunset      # Blue light filter (hyprsunset doesn't work with niri)
    xdg-desktop-portal-hyprland
    # wl-clipboard  # Already provided by wl-clipboard-rs in main config
    grim
    slurp
    wdisplays
    wlopm
    xwayland-satellite
    rose-pine-cursor
    rose-pine-hyprcursor
  ];

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
        scroll-factor 0.2
    }
    
    mouse {
        accel-speed 0.0
        accel-profile "flat"
    }

    tablet {
        map-to-output "eDP-1"
    }

    touch {
        map-to-output "eDP-1"
    }

    focus-follows-mouse max-scroll-amount="0%"
    // workspace-auto-back-and-forth
}

output "eDP-1" {
    mode "1920x1080@60"
    position x=0 y=0
    scale 1.0
    transform "normal"
    variable-refresh-rate on-demand=true
    focus-at-startup
    // hot-corners {
    //     top-left "none"
    // }
    // hot-corners {
    //     off
    // }
    // backdrop-color "#FF0000"
    // hot-corners {
    //     top-left "show-hud"
    //     top-right "show-workspace-grid"
    //     bottom-left "toggle-scratchpad"
    //     bottom-right "show-hotkey-overlay"
    // }
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
    default-column-display "normal"
    gaps 5
    center-focused-column "never"
    // empty-workspace-above-first

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }
    
    default-column-width { proportion 0.5; }
    
    focus-ring {
        // off
        width 2
        // active-color "#1e7bb8"
        // active-color "#FF6666"
        active-color "#953553"
        // inactive-color "#1a1a1a"
    }
    
    // border {
    //     off
    //     width 2
    //     active-color "#1e7bb8"
    //     inactive-color "#1a1a1a"
    // }

    shadow {
        on
        softness 30
        spread 5
        offset x=0 y=5
        draw-behind-window true
        color "#00000070"
    }

    tab-indicator {
        off
        // hide-when-single-tab
        // place-within-column
        // gap 5
        // width 4
        // length total-proportion=1.0
        // position "right"
        // gaps-between-tabs 2
        // corner-radius 8
        // active-color "red"
        // inactive-color "gray"
        // urgent-color "blue"

        // active-gradient from="#80c8ff" to="#bbddff" angle=45
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
        // urgent-gradient from="#800" to="#a33" angle=45
    }

    insert-hint {
        off
        // color "#ffc87f80"
        // gradient from="#ffbb6680" to="#ffc88080" angle=45 relative-to="workspace-view"
    }

    struts {
      left 0
      right 0
      top 2.5
      bottom 2.5
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

// window-rule {
//     match app-id="^org\.gnome\.Nautilus$"
//     default-column-width { fixed 800; }
// }
//
// window-rule {
//     match title="^(Volume Control)$"
//     default-column-width { fixed 800; }
//     open-floating true
// }
//
// window-rule {
//     match title="^(Picture-in-Picture)$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^polkit"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^fuzzel$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^nwg-look$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^pavucontrol$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^keepassxc$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^org\\\.gnome\\\.Settings$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^file-roller$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^Pcmanfm$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^obs$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^wdisplays$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^zathura$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^zoom$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^Lxappearance$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^ncmpcpp$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^viewnior$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^gucharmap$"
//     open-floating true
// }
//
// window-rule {
//     match app-id="^gnome-font$"
//     open-floating true
// }
//
// window-rule {
//     match title="^(Media viewer)$"
//     open-floating true
// }
//
// window-rule {
//     match title="^(Firefox — Sharing Indicator)$"
//     open-floating true
// }
//
// window-rule {
//     match title="^(GLava)$"
//     open-floating true
// }

spawn-at-startup "swaync"
spawn-at-startup "waybar"
spawn-at-startup "hyprpaper"
spawn-at-startup "hypridle"
spawn-at-startup "wlsunset" "-t" "4300"
spawn-at-startup "xhost" "+local:"
spawn-at-startup "lxqt-policykit-agent"
spawn-sh-at-startup "__NV_PRIME_RENDER_OFFLOAD=0 swayosd-server"

environment {
    ELECTRON_OZONE_PLATFORM_HINT "auto"
    XDG_CURRENT_DESKTOP "niri"
    XDG_SESSION_DESKTOP "niri" 
    XDG_SESSION_TYPE "wayland"
    QT_FONT_DPI "74"
    SAL_USE_VCLPLUGIN "qt5"
    QT_SCALE_FACTOR "1"
    SAL_FORCEDPI "70"
    MOZ_USE_XINPUT2 "1"
    DISPLAY ":0"
  ${lib.optionalString (hostName == "mishy") ''
    LIBVA_DRIVER_NAME "nvidia"
    GBM_BACKEND "nvidia-drm"
    __GLX_VENDOR_LIBRARY_NAME "nvidia"
    WLR_NO_HARDWARE_CURSORS "1"
    WLR_DRM_NO_ATOMIC "1"
  ''}
}

cursor {
    xcursor-theme "BreezeX-RosePine-Linux"
    xcursor-size 27

    hide-when-typing
    hide-after-inactive-ms 1000
}

binds {
    Mod+Shift+Slash { show-hotkey-overlay; }
    // Applications
    Mod+B repeat=false { spawn "zen-beta"; }
    Mod+Q { spawn "${if pkgs.stdenv.hostPlatform.isAarch64 then "LIBGL_ALWAYS_SOFTWARE=1 " else ""}ghostty"; }
    Mod+C repeat=false { close-window; }
    // Mod+Ctrl+C repeat=false { spawn "sh" "-c" "kill -9 $(niri msg focused-window | jq -r '.pid // empty')"; }
    Mod+Ctrl+C repeat=false { spawn-sh "kill -9 $(niri msg --json focused-window | jq -r '.pid // empty')"; }
    Mod+E repeat=false { spawn "nemo"; }
    Mod+V repeat=false { toggle-window-floating; }
    Mod+Shift+V repeat=false { switch-focus-between-floating-and-tiling; }

    Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
    Mod+Ctrl+Escape { quit; }

    // Focus movement (vi-like)
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+K { focus-window-up; }
    Mod+J { focus-window-down; }

    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }

    // Move windows
    Mod+Ctrl+H { move-column-left; }
    Mod+Ctrl+L { move-column-right; }
    Mod+Ctrl+K { move-window-up; }
    Mod+Ctrl+J { move-window-down; }

    Mod+Shift+K { move-column-to-workspace-up; }
    Mod+Shift+J { move-column-to-workspace-down; }

    Mod+Shift+P { power-off-monitors; }

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
    Mod+Shift+1 repeat=false { move-column-to-workspace 1; }
    Mod+Shift+2 repeat=false { move-column-to-workspace 2; }
    Mod+Shift+3 repeat=false { move-column-to-workspace 3; }
    Mod+Shift+4 repeat=false { move-column-to-workspace 4; }
    Mod+Shift+5 repeat=false { move-column-to-workspace 5; }
    Mod+Shift+6 repeat=false { move-column-to-workspace 6; }
    Mod+Shift+7 repeat=false { move-column-to-workspace 7; }
    Mod+Shift+8 repeat=false { move-column-to-workspace 8; }
    Mod+Shift+9 repeat=false { move-column-to-workspace 9; }
    Mod+Shift+0 repeat=false { move-column-to-workspace 10; }
    
    // Move to F-key workspaces (11-22)
    Mod+Shift+F1 repeat=false { move-column-to-workspace 11; }
    Mod+Shift+F2 repeat=false { move-column-to-workspace 12; }
    Mod+Shift+F3 repeat=false { move-column-to-workspace 13; }
    Mod+Shift+F4 repeat=false { move-column-to-workspace 14; }
    Mod+Shift+F5 repeat=false { move-column-to-workspace 15; }
    Mod+Shift+F6 repeat=false { move-column-to-workspace 16; }
    Mod+Shift+F7 repeat=false { move-column-to-workspace 17; }
    Mod+Shift+F8 repeat=false { move-column-to-workspace 18; }
    Mod+Shift+F9 repeat=false { move-column-to-workspace 19; }
    Mod+Shift+F10 repeat=false { move-column-to-workspace 20; }
    Mod+Shift+F11 repeat=false { move-column-to-workspace 21; }
    Mod+Shift+F12 repeat=false { move-column-to-workspace 22; }

    // Scroll through workspaces
    Mod+Up repeat=false { focus-workspace-up; }
    Mod+Down repeat=false { focus-workspace-down; }
    Mod+Page_Up repeat=false { focus-workspace-up; }
    Mod+Page_Down repeat=false { focus-workspace-down; }

    Mod+Shift+Up repeat=false { move-column-to-workspace-up; }
    Mod+Shift+Down repeat=false { move-column-to-workspace-down; }
    Mod+Shift+Page_Up repeat=false { move-column-to-workspace-up; }
    Mod+Shift+Page_Down repeat=false { move-column-to-workspace-down; }
    
    // Last workspace
    Mod+grave repeat=false { focus-workspace-previous; }
    
    // Special workspace equivalents
    // Mod+Return { focus-workspace "empty"; }
    Mod+T repeat=false { move-column-to-workspace-down; }

    // Launchers (force Wayland mode by unsetting DISPLAY)
    Ctrl+Semicolon { spawn-sh "ROFI_WIDTH=700 ROFI_LINES=10 rofi -show combi"; }
    Ctrl+Apostrophe { spawn "rofi-bluetooth"; }
    Ctrl+Shift+Apostrophe { spawn-sh "ROFI_WIDTH=700 ROFI_LINES=10 rofi -show filebrowser"; }
    Ctrl+Shift+Semicolon { spawn-sh "ROFI_WIDTH=700 ROFI_LINES=10 rofi -show run"; }
    Ctrl+M { spawn-sh "ROFI_WIDTH=850 rofi-pulse-select sink"; }
    Ctrl+Shift+M { spawn-sh "ROFI_WIDTH=950 rofi-pulse-select source"; }
    Ctrl+BracketRight { spawn-sh "rofimoji"; }
    Ctrl+Backslash { spawn-sh "rofi -show calc -no-show-match -no-sort -automatic-save-to-history -calc-command-history -calc-command \"echo -n '{result}' | wl-copy\""; }
    
    // Fullscreen
    F11 { fullscreen-window; }
    Mod+Ctrl+F11 { toggle-windowed-fullscreen; }

    // Screenshots
    Print { screenshot; }
    Shift+Print { screenshot-screen; }
    Mod+Print { screenshot-window; }

    // Notifications
    // Ctrl+Shift+Q { spawn-sh "niri msg action do-screen-transition && swaync-client -t"; }
    Ctrl+Shift+Q { spawn "swaync-client" "-t"; }
    Ctrl+Shift+X { spawn "swaync-client" "--hide-latest"; }

    // Audio
    XF86AudioRaiseVolume allow-when-locked=true { spawn "swayosd-client" "--output-volume" "+2"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "swayosd-client" "--output-volume" "-2"; }
    XF86AudioMute allow-when-locked=true { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
    F7 allow-when-locked=true { spawn "swayosd-client" "--output-volume" "+2"; }
    F6 allow-when-locked=true { spawn "swayosd-client" "--output-volume" "-2"; }
    
    // Per-app volume controls
    Ctrl+XF86AudioRaiseVolume { spawn-sh "wpctl set-volume -l 1.0 -p $(niri msg --json focused-window | jq -r '.pid // empty') 2%+; notify-send -u low -t 1000 -r 10 \"2%+ Volume for $(niri msg --json focused-window | jq -r '.title // \"Unknown\"')\""; }
    Ctrl+XF86AudioLowerVolume { spawn-sh "wpctl set-volume -l 1.0 -p $(niri msg --json focused-window | jq -r '.pid // empty') 2%-; notify-send -u low -t 1000 -r 10 \"2%- Volume for $(niri msg --json focused-window | jq -r '.title // \"Unknown\"')\""; }
    Ctrl+XF86AudioMute { spawn-sh "wpctl set-mute -p $(niri msg --json focused-window | jq -r '.pid // empty') toggle; notify-send -u low -t 1000 -r 10 \"Toggle Mute for $(niri msg --json focused-window | jq -r '.title // \"Unknown\"')\""; }
    Ctrl+F7 { spawn-sh "wpctl set-volume -l 1.0 -p $(niri msg --json focused-window | jq -r '.pid // empty') 2%+; notify-send -u low -t 1000 -r 10 \"2%+ Volume for $(niri msg --json focused-window | jq -r '.title // \"Unknown\"')\""; }
    Ctrl+F6 { spawn-sh "wpctl set-volume -l 1.0 -p $(niri msg --json focused-window | jq -r '.pid // empty') 2%-; notify-send -u low -t 1000 -r 10 \"2%- Volume for $(niri msg --json focused-window | jq -r '.title // \"Unknown\"')\""; }
    Ctrl+F10 { spawn-sh "wpctl set-mute -p $(niri msg --json focused-window | jq -r '.pid // empty') toggle; notify-send -u low -t 1000 -r 10 \"Toggle Mute for $(niri msg --json focused-window | jq -r '.title // \"Unknown\"')\""; }

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
    XF86AudioPlay allow-when-locked=true { spawn "swayosd-client" "--playerctl=play"; }
    XF86AudioPause allow-when-locked=true { spawn "swayosd-client" "--playerctl=pause"; }
    XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
    XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
    F8 allow-when-locked=true { spawn "playerctl" "previous"; }
    F9 allow-when-locked=true { spawn "playerctl" "next"; }
    F10 allow-when-locked=true { spawn "swayosd-client" "--playerctl=play-pause"; }

    // Window management (group management from Hyprland - niri doesn't have groups but these are window navigation)
    // Mod+Tab { focus-window-down-or-column-right; }
    // Mod+Shift+Tab { focus-window-up-or-column-left; }
    // Alt+Tab { focus-window-down-or-column-right; }
    
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
    Mod+BracketLeft { consume-or-expel-window-left; }
    Mod+BracketRight { consume-or-expel-window-right; }

    // Layout management
    Mod+Comma { consume-window-into-column; }
    Mod+Period { expel-window-from-column; }

    Mod+R { switch-preset-column-width; }
    Mod+Shift+R { switch-preset-window-height; }
    Mod+F { maximize-column; }
    Mod+Ctrl+F { expand-column-to-available-width; }

    // Finer width adjustments.
    // This command can also:
    // * set width in pixels: "1000"
    // * adjust width in pixels: "-5" or "+5"
    // * set width as a percentage of screen width: "25%"
    // * adjust width as a percentage of screen width: "-10%" or "+10%"
    // Pixel sizes use logical, or scaled, pixels. I.e. on an output with scale 2.0,
    // set-column-width "100" will make the column occupy 200 physical screen pixels.
    Alt+Shift+L { set-column-width "+30"; }
    Alt+Shift+H { set-column-width "-30"; }
    Alt+Ctrl+L { set-column-width "+90"; }
    Alt+Ctrl+H { set-column-width "-90"; }

    // Finer height adjustments when in column with other windows.
    Alt+Shift+K { set-window-height "+30"; }
    Alt+Shift+J { set-window-height "-30"; }
    Alt+Ctrl+K { set-window-height "+90"; }
    Alt+Ctrl+J { set-window-height "-90"; }

    // Open/close the Overview: a zoomed-out view of workspaces and windows.
    // You can also move the mouse into the top-left hot corner,
    // or do a four-finger swipe up on a touchpad.
    Mod+O repeat=false { toggle-overview; }
    
    // Resize functionality - use column width switching and window movement instead
    // Mod+Shift+R { switch-preset-column-width; }
    
    // Mouse bindings for window management
    Mod+WheelScrollDown { focus-workspace-down; }
    Mod+WheelScrollUp { focus-workspace-up; }
    Mod+Shift+WheelScrollDown { move-column-to-workspace-down; }
    Mod+Shift+WheelScrollUp { move-column-to-workspace-up; }

    Mod+WheelScrollRight      { focus-column-right; }
    Mod+WheelScrollLeft       { focus-column-left; }
    Mod+Ctrl+WheelScrollRight { move-column-right; }
    Mod+Ctrl+WheelScrollLeft  { move-column-left; }
    
    // Caps lock indicator (removed - invalid syntax in niri)
    
    // Monitor management keybindings
    Mod+Ctrl+Shift+Page_Up { move-workspace-to-monitor-up; }
    Mod+Ctrl+Shift+Page_Down { move-workspace-to-monitor-down; }
    Mod+Ctrl+Shift+Up { move-workspace-to-monitor-up; }
    Mod+Ctrl+Shift+Down { move-workspace-to-monitor-down; }
    Mod+Ctrl+Shift+Left { move-workspace-to-monitor-left; }
    Mod+Ctrl+Shift+Right { move-workspace-to-monitor-right; }
    
    // Mouse button bindings removed - niri uses different mouse binding syntax
}

window-rule {
    geometry-corner-radius 5 5 5 5
    clip-to-geometry true
    // baba-is-float true
}

// Indicate screencasted windows with red colors.
window-rule {
    match is-window-cast-target=true

    focus-ring {
        active-color "#f38ba8"
        inactive-color "#7d0d2d"
    }

    border {
        inactive-color "#7d0d2d"
    }

    shadow {
        color "#7d0d2d70"
    }

    tab-indicator {
        active-color "#f38ba8"
        inactive-color "#7d0d2d"
    }
}

gestures {
    // dnd-edge-view-scroll {
    //     trigger-width 30
    //     delay-ms 100
    //     max-speed 1500
    // }
    hot-corners {
        off
    }
}

animations {
    // Uncomment to turn off all animations.
    // You can also put "off" into each individual animation to disable it.
    // off

    // Slow down all animations by this factor. Values below 1 speed them up instead.
    // slowdown 3.0

    // Individual animations.

    workspace-switch {
        spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
    }

    window-open {
        duration-ms 150
        curve "ease-out-expo"
    }

    window-close {
        duration-ms 150
        curve "ease-out-quad"
    }

    horizontal-view-movement {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
    }

    window-movement {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
    }

    window-resize {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
    }

    config-notification-open-close {
        spring damping-ratio=0.6 stiffness=1000 epsilon=0.001
    }

    exit-confirmation-open-close {
        spring damping-ratio=0.6 stiffness=500 epsilon=0.01
    }

    screenshot-ui-open {
        duration-ms 200
        curve "ease-out-quad"
    }

    overview-open-close {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
    }
}

// animations {
//     slowdown 1.0
//     window-open {
//         duration-ms 150
//         curve "ease-out-expo"
//     }
//     window-close {
//         duration-ms 150
//         curve "ease-out-expo"
//     }
//     horizontal-view-movement {
//         duration-ms 200
//         curve "ease-out-expo"
//     }
//     workspace-switch {
//         duration-ms 200
//         curve "ease-out-expo"
//     }
//     window-movement {
//         duration-ms 200
//         curve "ease-out-expo"
//     }
//     window-resize {
//         duration-ms 200
//         curve "ease-out-expo"
//     }
// }

// overview {
//    zoom 0.5
//     workspace-shadow {
//         off
//     }
// }
  '';

  # Use existing hyprpaper and hypridle services from hyprland module
  # These will be configured to work with niri as well
  
  # The hyprlock and hypridle configs are already set up in the hyprland module
  # and will work with niri since they're independent of the compositor
}
