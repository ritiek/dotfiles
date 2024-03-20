{ config, pkgs, lib, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/refs/heads/release-23.11.zip";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];


  home-manager.users.ritiek = {
    /* The home.stateVersion option does not have a default and must be set */
    home = {
      stateVersion = "23.11";
      packages = with pkgs; [
        wezterm
	# spotify
	google-chrome
	hyprpaper
	swaynotificationcenter
	swayosd
	# waybar
	# rofi-wayland
	playerctl
	nwg-look
	armcord
	# bitwarden-desktop
	nur.repos.nltch.spotify-adblock
      ];
    };
    /* Here goes the rest of your home-manager config, e.g. home.packages = [ pkgs.foo ]; */
    programs.mpv = {
      enable = true;
      config = {
        sub-font = "Noto Sans Regular";
        sub-font-size = 38;
        sid = 2;
        alang = "jpn";
        slang = "eng";
        no-sub-ass = "";
        force-seekable = "";
      };
    };
    programs.sioyek = {
      enable = true;
      config = {
        "startup_commands" = "toggle_statusbar";
        "default_dark_mode" = "1";
        "should_launch_new_window" = "1";
      };
    };
    programs.zellij = {
      enable = true;
      settings = {
        theme = "dracula";
        themes = {
          dracula = {
            fg = [ 248 248 242 ];
            bg = [ 40 42 54 ];
            black = [ 0 0 0 ];
            red = [ 255 85 85 ];
            green = [ 241 250 140 ];
            yellow = [ 241 250 164 ];
            blue = [ 98 114 164 ];
            magenta = [ 255 121 198 ];
            cyan = [ 139 233 253 ];
            white = [ 255 255 255 ];
            orange = [ 255 184 108 ];
	  };
        };
      };
    };
    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
	  layer = "top";
          output = [
	    "eDP-1"
	    "HDMI-A-1"
	  ];
          position = "bottom";
          spacing = 0;
          height = 34;
          modules-left = [
            "custom/logo"
            "hyprland/workspaces"
            # "hyprland/window"
          ];
          modules-center = [
            "clock"
          ];
          modules-right = [
            "tray"
            "battery"
            "custom/notification"
            "custom/power"
          ];
          "wlr/taskbar" = {
            format = "{icon}";
            on-click = "activate";
            on-click-right = "fullscreen";
            icon-theme = "WhiteSur";
            icon-size = 25;
            tooltip-format = "{title}";
          };
          "hyprland/workspaces" = {
            on-click = "activate";
            format = "{icon}";
            all-outputs = true;
            format-icons = {
              default = "";
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "4" = "4";
              "5" = "5";
              "6" = "6";
              "7" = "7";
              "8" = "8";
              "9" = "9";
              active = "󱓻";
              urgent = "󱓻";
            };
            persistent-workspaces = {
              "1" = [];
              "2" = [];
              "3" = [];
              "4" = [];
              "5" = [];
            };
          };
          "hyprland/window" = {
            max-length = 200;
            separate-outputs = true;
          };
          tray = {
            spacing = 10;
          };
          clock = {
            tooltip-format = "<tt>{calendar}</tt>";
            format-alt = "  {:%a, %d %b %Y}";
            format = "  {:%I:%M %p}";
          };
          battery = {
            format = "{capacity}% {icon}";
            format-icons = {
              charging = [
                "󰢜"
                "󰂆"
                "󰂇"
                "󰂈"
                "󰢝"
                "󰂉"
                "󰢞"
                "󰂊"
                "󰂋"
                "󰂅"
              ];
              default = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            format-full = "Charged ";
            interval = 5;
            states = {
              warning = 20;
              critical = 10;
            };
            tooltip = false;
          };
          # "custom/notification" = {
          #   tooltip = false;
          #   format = "{} {icon}";
          #   format-icons = {
          #     notification = "<span foreground='red'><sup></sup></span>";
          #     none = "";
          #     dnd-notification = "<span foreground='red'><sup></sup></span>";
          #     dnd-none = "";
          #     inhibited-notification = "<span foreground='red'><sup></sup></span>";
          #     inhibited-none = "";
          #     dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
          #     dnd-inhibited-none = "";
          #   };
          #   return-type = "json";
          #   exec-if = "which swaync-client";
          #   exec = "swaync-client -swb";
          #   on-click = "swaync-client -t -sw";
          #   on-click-right = "swaync-client -d -sw";
          #   icon-size = 25;
          #   escape = true;
          # };
        };
      };
      style = ''
* {
  border: none;
  border-radius: 0;
  min-height: 0;
  font-family: Material Design Icons, JetBrainsMono Nerd Font;
  font-size: 13px;
}

window#waybar {
  background-color: #181825;
  transition-property: background-color;
  transition-duration: 0.5s;
}

window#waybar.hidden {
  opacity: 0.5;
}

#workspaces {
  background-color: transparent;
}

#workspaces button {
  all: initial; /* Remove GTK theme values (waybar #1351) */
  min-width: 0; /* Fix weird spacing in materia (waybar #450) */
  box-shadow: inset 0 -3px transparent; /* Use box-shadow instead of border so the text isn't offset */
  padding: 6px 18px;
  margin: 6px 3px;
  border-radius: 4px;
  background-color: #1e1e2e;
  color: #cdd6f4;
}

#workspaces button.active {
  color: #1e1e2e;
  background-color: #cdd6f4;
}

#workspaces button:hover {
 box-shadow: inherit;
 text-shadow: inherit;
 color: #1e1e2e;
 background-color: #cdd6f4;
}

#workspaces button.urgent {
  background-color: #f38ba8;
}

#memory,
#custom-power,
#battery,
#backlight,
#pulseaudio,
#network,
#clock,
#tray {
  border-radius: 4px;
  margin: 6px 3px;
  padding: 6px 12px;
  background-color: #1e1e2e;
  color: #181825;
}

#custom-power {
  margin-right: 6px;
}

#custom-logo {
  padding-right: 7px;
  padding-left: 7px;
  margin-left: 5px;
  font-size: 15px;
  border-radius: 8px 0px 0px 8px;
  color: #1793d1;
}

#memory {
  background-color: #fab387;
}
#battery {
  background-color: #f38ba8;
}
@keyframes blink {
  to {
    background-color: #f38ba8;
    color: #181825;
  }
}

#battery.warning,
#battery.critical,
#battery.urgent {
  background-color: #ff0048;
  color: #181825;
  animation-name: blink;
  animation-duration: 0.5s;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
  animation-direction: alternate;
}
#battery.charging {
  background-color: #a6e3a1;
}

#backlight {
  background-color: #fab387;
}

#pulseaudio {
  background-color: #f9e2af;
}

#network {
  background-color: #94e2d5;
  padding-right: 17px;
}

#clock {
  font-family: JetBrainsMono Nerd Font;
  background-color: #cba6f7;
}

#custom-power {
  background-color: #f2cdcd;
}

#custom-notification {
  font-family: "NotoSansMono Nerd Font";
}


tooltip {
border-radius: 8px;
padding: 15px;
background-color: #131822;
}

tooltip label {
padding: 5px;
background-color: #131822;
}
      '';
    };
    wayland.windowManager.hyprland = {
      enable = true;
      enableNvidiaPatches = true;
      # xwayland.enable = false;
      systemd.enable = true;
      extraConfig = ''
########################################################################################
AUTOGENERATED HYPR CONFIG.
PLEASE USE THE CONFIG PROVIDED IN THE GIT REPO /examples/hypr.conf AND EDIT IT,
OR EDIT THIS ONE ACCORDING TO THE WIKI INSTRUCTIONS.
########################################################################################

autogenerated = 0 # remove this line to remove the warning

# Make Hyprland use Nvidia graphics
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_DRM_NO_ATOMIC,1

# env = __NV_PRIME_RENDER_OFFLOAD,1
# env = __VK_LAYER_NV_optimus,NVIDIA_only

# Prioritize card 0 (NVIDIA) over card 1 (Intel)
env = WLR_DRM_DEVICES,/dev/dri/card0:/dev/dri/card1

env = XCURSOR_SIZE,24

$mainMod = SUPER

$primaryMonitor = eDP-1
$primaryMonitorBlk = intel_backlight

$screenPadMonitor = HDMI-A-2
$screenPadMonitorBlk = asus::screenpad

$externalMonitor = HDMI-A-1


# KDE cursor
exec-once = hyprctl setcursor Qogir 24

# Notification daemon
exec-once = swaync
# Status bar
exec-once = waybar

# Audio
exec-once = pipewire
exec-once = wireplumber
exec-once = pipewire-pulse

# Volume/Brightness OSD
exec-once = swayosd-server

# Wallpaper
exec-once = hyprpaper

# Auto screen locking
exec-once = swayidle -w

# Pkexec agent
exec-once = xhost +local:
exec-once = /usr/lib/polkit-kde-authentication-agent-1

# Start nightlight daemon
# This isn't exec-once as it seems to die when swayidle kicks in
exec = wl-gammarelay-rs
exec = sleep 0.2s && busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 3600


source ~/.config/hypr/hyprland/var.conf

# Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
bind = $mainMod, Q, exec, wezterm
# This doesn't set $WAYLAND_DISPLAY which makes waybar not work.
# bind = $mainMod, Q, exec, env -u WAYLAND_DISPLAY wezterm
bind = $mainMod, B, exec, google-chrome-stable
bind = $mainMod, C, killactive,
# Exits hyprland, when would i need this?
# bind = $mainMod, M, exit,
bind = $mainMod, E, exec, nemo
bind = $mainMod, V, togglefloating,
bind = $mainMod, V, resizeactive, exact 900 700

bind = $mainMod, TAB, pin,
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, S, togglesplit, # dwindle
# Application launcher
bind = $mainMod, R, exec, rofi -show combi
bind = $mainMod SHIFT, R, exec, rofi-bluetooth
bind = $mainMod CTRL, R, exec, rofi -show filebrowser

# Move focus with mainMod + arrow keys
# bind = $mainMod, left, movefocus, l
# bind = $mainMod, right, movefocus, r
# bind = $mainMod, up, movefocus, u
# bind = $mainMod, down, movefocus, d
bind = $mainMod, h, movefocus, l
bind = $mainMod, l, movefocus, r
bind = $mainMod, k, movefocus, u
bind = $mainMod, j, movefocus, d

# Switch to next or previous workspace with mainMod + left/right arrow key
bind = $mainMod, left, workspace, -1
bind = $mainMod, right, workspace, +1
# Switch to next or previous workspace with mainMod + SFHIT h/l
bind = $mainMod SHIFT, h, workspace, -1
bind = $mainMod SHIFT, l, workspace, +1

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10
# Switch workspaces with mainMod + [F1-F12]
bind = $mainMod, F1, workspace, 11
bind = $mainMod, F2, workspace, 12
bind = $mainMod, F3, workspace, 13
bind = $mainMod, F4, workspace, 14
bind = $mainMod, F5, workspace, 15
bind = $mainMod, F6, workspace, 16
bind = $mainMod, F7, workspace, 17
bind = $mainMod, F8, workspace, 18
bind = $mainMod, F9, workspace, 19
bind = $mainMod, F10, workspace, 20
bind = $mainMod, F11, workspace, 21
bind = $mainMod, F12, workspace, 22

# Swtich between last workspace with mainMod + `
# bind = $mainMod, grave, workspace, previous
bind = $mainMod, grave, focusurgentorlast

bind = $mainMod, G, togglegroup
bind = $mainMod SHIFT, G, lockgroups, toggle
bind = $mainMod, Tab, changegroupactive, f
bind = $mainMod SHIFT, Tab, changegroupactive, b
bind = CTRL,  1, changegroupactive, 1
bind = CTRL,  2, changegroupactive, 2
bind = CTRL,  3, changegroupactive, 3
bind = CTRL,  4, changegroupactive, 4
bind = CTRL,  5, changegroupactive, 5
bind = CTRL,  6, changegroupactive, 6
bind = CTRL,  7, changegroupactive, 7
bind = CTRL,  8, changegroupactive, 8
bind = CTRL,  9, changegroupactive, 9
bind = CTRL, 10, changegroupactive, 10

bind = ALT, Tab, cyclenext,
bind = ALT, Tab, bringactivetotop,

# Move active window to next or previous workspace with mainMod + SHIFT + left/right arrow key
bind = $mainMod SHIFT, left, movetoworkspace, -1
bind = $mainMod SHIFT, right, movetoworkspace, +1
# Move active window to next or previous workspace with mainMod + SHIFT + h/l
bind = $mainMod CTRL SHIFT, h, movetoworkspace, -1
bind = $mainMod CTRL SHIFT, l, movetoworkspace, +1

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10
# Move active window to a workspace with mainMod + SHIFT + [F1-F12]
bind = $mainMod SHIFT, F1, movetoworkspace, 11
bind = $mainMod SHIFT, F2, movetoworkspace, 12
bind = $mainMod SHIFT, F3, movetoworkspace, 13
bind = $mainMod SHIFT, F4, movetoworkspace, 14
bind = $mainMod SHIFT, F5, movetoworkspace, 15
bind = $mainMod SHIFT, F6, movetoworkspace, 16
bind = $mainMod SHIFT, F7, movetoworkspace, 17
bind = $mainMod SHIFT, F8, movetoworkspace, 18
bind = $mainMod SHIFT, F9, movetoworkspace, 19
bind = $mainMod SHIFT, F10, movetoworkspace, 20
bind = $mainMod SHIFT, F11, movetoworkspace, 21
bind = $mainMod SHIFT, F12, movetoworkspace, 22
# Move to first empty workspace
bind = $mainMod, Return, workspace, empty

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = ALT, mouse:272, resizewindow

# Output volume key bindings
$outputVolumeUpCommand = swayosd-client --output-volume +2
$outputVolumeDownCommand = swayosd-client --output-volume -2
$outputVolumeMuteCommand = swayosd-client --output-volume mute-toggle
bindel = , XF86AudioRaiseVolume, exec, $outputVolumeUpCommand
bindel = , XF86AudioLowerVolume, exec, $outputVolumeDownCommand
bindel = , XF86AudioMute, exec, $outputVolumeMuteCommand
# bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 2%+
# bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
# bindel = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = , F7, exec, $outputVolumeUpCommand
bindel = , F6, exec, $outputVolumeDownCommand

# Input volume key bindings
$inputVolumeUpCommand = swayosd-client --input-volume +5
$inputVolumeDownCommand = swayosd-client --input-volume -5
$inputVolumeMuteCommand = swayosd-client --input-volume mute-toggle
bindel = SHIFT, XF86AudioRaiseVolume, exec, $inputVolumeUpCommand
bindel = SHIFT, XF86AudioLowerVolume, exec, $inputVolumeDownCommand
bindel = SHIFT, XF86AudioMute, exec, $inputVolumeMuteCommand
bindel = SHIFT, F7, exec, $inputVolumeUpCommand
bindel = SHIFT, F6, exec, $inputVolumeDownCommand

# Brightness key bindings
bindel = , XF86MonBrightnessUp, exec, swayosd-client --device $primaryMonitorBlk --brightness raise
bindel = , XF86MonBrightnessDown, exec, swayosd-client --device $primaryMonitorBlk --brightness lower

bindel = SHIFT, XF86MonBrightnessUp, exec, swayosd-client --device $screenPadMonitorBlk --brightness raise
bindel = SHIFT, XF86MonBrightnessDown, exec, swayosd-client --device $screenPadMonitorBlk --brightness lower
# bindel = , XF86MonBrightnessUp, exec, brillo -q -A 2
# bindel = , XF86MonBrightnessDown, exec, brillo -q -U 2

# Night-light key bindings
# Wait for daemon to start and then set default temperature
bindel = $mainMod, XF86MonBrightnessUp, exec, busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n +100
bindel = $mainMod, XF86MonBrightnessDown, exec, busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n -100

# Multimedia keys
bind = , XF86AudioPlay, exec, playerctl play
bind = , XF86AudioPause, exec, playerctl pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous
bind = , XF86AudioPlay, exec, playerctl play
# F8 previous track
bindl = , F8, exec, playerctl previous
# F9 next track
bindl = , F9, exec, playerctl next
# F10 play-pause track
bindl = , F10, exec, playerctl play-pause

# Resize windows
# binde = $mainMod SHIFT, left, resizeactive, -30 0
# binde = $mainMod SHIFT, right, resizeactive, 30 0
# binde = $mainMod SHIFT, down, resizeactive, 0 30
# binde = $mainMod SHIFT, up, resizeactive, 0 -30
bind = ALT, R, submap, resize
submap = resize
binde = , l, resizeactive, 30 0
binde = , h, resizeactive, -30 0
binde = , k, resizeactive, 0 -30
binde = , j, resizeactive, 0 30
bind = , escape, submap, reset
submap = reset

bind = $mainMod, F, togglespecialworkspace
bind = $mainMod, W, movetoworkspace, special
bind = $mainMod, T, movetoworkspace, e+0
# bind = $mainMod, T, togglespecialworkspace

bind = $mainMod CTRL SHIFT, 1, movecurrentworkspacetomonitor, eDP-1
bind = $mainMod CTRL SHIFT, 2, movecurrentworkspacetomonitor, HDMI-A-1
bind = $mainMod CTRL SHIFT, 0, movecurrentworkspacetomonitor, HDMI-A-2

# Move windows
bind = $mainMod CTRL, H, movewindow, l
bind = $mainMod CTRL, L, movewindow, r
bind = $mainMod CTRL, K, movewindow, u
bind = $mainMod CTRL, J, movewindow, d

# Fullscreen
bind = , F11, fullscreen
bind = $mainMod, F11, fakefullscreen

# Sway Notification Center
bind = CTRL SHIFT, Q, exec, swaync-client -t
bind = CTRL SHIFT, X, exec, swaync-client --hide-latest

# Screenshot
bind = , Print, exec, hyprshot --clipboard-only -m region
bind = $mainMod, Print, exec, hyprshot -m output -- imv-dir
bind = $mainMod SHIFT, Print, exec, hyprshot --clipboard-only -m window


# workspace =  special, gapsin:50, gapsout:100
workspace =  1, monitor:$primaryMonitor
workspace =  2, monitor:$externalMonitor
workspace =  3, monitor:$primaryMonitor
workspace =  4, monitor:$externalMonitor
workspace =  5, monitor:$primaryMonitor
workspace =  6, monitor:$externalMonitor
workspace =  7, monitor:$primaryMonitor
workspace =  8, monitor:$externalMonitor
workspace =  9, monitor:$primaryMonitor
workspace = 10, monitor:$screenPadMonitor, default:true, persistent:true

# windowrule = float, Bitwarden
# windowrule = size 1100 800, Bitwarden
# windowrule = center, Bitwarden
windowrule = float, title:^(Bitwarden)$, class:^(Google-chrome)$
windowrule = float, polkit
windowrule = float, file_progress
windowrule = float, confirm
windowrule = float, dialog
windowrule = float, download
windowrule = float, notification
windowrule = float, error
windowrule = float, splash
windowrule = float, confirmreset
windowrule = float, title:Open File
windowrule = float, title:branchdialog
windowrule = float, zoom
# windowrule = float, vlc
windowrule = float, Lxappearance
windowrule = float, nwg-look
windowrule = float, ncmpcpp
windowrule = float, viewnior
windowrule = float, pavucontrol-qt
windowrule = float, gucharmap
windowrule = float, gnome-font
windowrule = float, org.gnome.Settings
windowrule = float, file-roller
# windowrule = float, nautilus
# windowrule = float, nemo
# windowrule = float, thunar
windowrule = float, Pcmanfm
windowrule = float, obs
windowrule = float, wdisplays
windowrule = float, zathura
windowrule = float, *.exe
windowrule = fullscreen, wlogout
windowrule = float, title:wlogout
windowrule = fullscreen, title:wlogout
windowrule = float, keepassxc
windowrule = idleinhibit focus, mpv
windowrule = idleinhibit fullscreen, firefox
windowrule = float, title:^(Media viewer)$
windowrule = float, title:^(Transmission)$
windowrule = float, title:^(Volume Control)$
windowrule = float, title:^(Picture-in-Picture)$
windowrule = float, title:^(Firefox — Sharing Indicator)$
windowrule = move 0 0, title:^(Firefox — Sharing Indicator)$
windowrule = size 800 600, title:^(Volume Control)$
windowrule = move 75 44%, title:^(Volume Control)$
windowrulev2 = opacity 0.85 0.85, class:^(Alacritty|code-oss)$
windowrulev2 = tile, 0.85, class:^(ballistica.*|bombsquad)$

# See https://wiki.hyprland.org/Configuring/Monitors/
# monitor=name,resolution,position,scale
#
# Main monitor
monitor = $primaryMonitor, preferred, 0x0, 1.0
#
# Screenpad
# monitor = $screenPadMonitor, disable
# 0x1180 makes me not accidentally move my mouse to it.
monitor = $screenPadMonitor, highres, 0x2080, 2.666667, transform, 3
#
# External Monitor
# monitor = $externalMonitor, preferred, 1920x0, 1.0
monitor = $externalMonitor, preferred, 0x0, 1.0, mirror, eDP-1

# For all categories, see https://wiki.hyprland.org/Configuring/Variables/
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    touchpad {
        natural_scroll = yes
    }
    sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
}

general {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more
    gaps_in = 5
    gaps_out = 10
    border_size = 2

    # col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    # col.inactive_border = rgba(595959aa)

    # col.active_border = 0xffcba6f7
    # col.inactive_border = 0xff313244

    col.active_border = rgb(268bd2) # rgb(6272a4) # or rgb(44475a)
    col.inactive_border = rgb(1a1a1a)

    no_border_on_floating = false
    layout = dwindle
    # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
    allow_tearing = true
}

decoration {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more
    rounding = 5
    active_opacity = 1.0
    inactive_opacity = 1.0
    blur {
        enabled = yes
        size = 10
        passes = 1
        new_optimizations = on
    }
    drop_shadow = yes
    shadow_ignore_window = true
    shadow_range = 4
    shadow_offset = 2 2 
    shadow_render_power = 2
    col.shadow= 0x66000000
}

animations {
    enabled = yes
    # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05

    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
    pseudotile = yes # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = yes # you probably want this
    special_scale_factor = 0.9
}

master {
    # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
    new_is_master = true
}

gestures {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more
    workspace_swipe = on
}

misc {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more
    force_default_wallpaper = 0 # Set to 0 to disable the anime mascot wallpapers
    disable_hyprland_logo = true
    disable_splash_rendering = true
}

device:epic-mouse-v1 {
    sensitivity = -0.5
}
      '';
    };
    gtk = {
      enable = true;
      cursorTheme = {
        name = "Qogir";
	package = pkgs.qogir-icon-theme;
        size = 24;
      };
      font = {
        name = "Cantarell";
        package = pkgs.cantarell-fonts;
	size = 11;
      };
      iconTheme = {
        name = "Dracula";
        package = pkgs.dracula-icon-theme;
      };
      # theme = {
      #   name = "Catppucin-Mocha-Standard-Red-Dark";
      #   package = pkgs.catppuccin-gtk.override {
      #     # accents = [ "lavender" ];
      #     accents = [ "red-dark" ];
      #     size = "standard";
      #     variant = "mocha";
      #   };
      # };
      theme = {
        name = "Dracula";
        package = pkgs.dracula-theme;
      };
      gtk3.extraConfig = {
        gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
        gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
        gtk-button-images = 0;
        gtk-menu-images = 0;
        gtk-enable-event-sounds = 1;
        gtk-enable-input-feedback-sounds = 0;
        gtk-xft-antialias = 1;
        gtk-xft-hinting = 1;
        gtk-xft-hintstyle = "hintslight";
        gtk-xft-rgba = "rgb";
        gtk-application-prefer-dark-theme = 1;
      };
    };
    programs.command-not-found.enable = true;
    programs.btop = {
      enable = true;
      settings = {
        color_theme = "adapta";
	vim_keys = true;
	cpu_graph_lower = "iowait";
      };
    };
    programs.git = {
      enable = true;
      delta = {
        enable = true;
	options = {
	  decorations = {
	    commit-decoration-style = "bold yellow box ul";
            file-style = "bold yellow ul";
            file-decoration-style = "none";
	  };
	  features = "line-numbers decorations";
          whitespace-error-style = "22 reverse";
          plus-color = "#012800";
          minus-color = "#340001";
          syntax-theme = "Monokai Extended";
	  # diff-so-fancy = true;
	};
      };
    };
    programs.wezterm = {
      enable = true;
      extraConfig = ''
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

wezterm.on('toggle-colorscheme', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.color_scheme then
    overrides.color_scheme = 'Dracula'
  else
    overrides.color_scheme = nil
  end
  window:set_config_overrides(overrides)
end)

-- This is where you actually apply your config choices

config.enable_wayland = false
-- config.color_scheme = 'Dracula'
config.color_scheme = 'Tartan (terminal.sexy)'
config.hide_tab_bar_if_only_one_tab = true
config.font = wezterm.font(
  "FantasqueSansM Nerd Font Mono", {
    stretch = 'Expanded',
    weight = 'Regular'
  }
)
config.font_size = 12.2
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.initial_rows = 30
config.initial_cols = 90
config.keys = {
  -- Disable the default Alt+Enter fullscreen behaviour as
  -- this is used by Neovim GitHub Copilot to synthesize
  -- solutions.
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.DisableDefaultAssignment,
  },
  {
    key = 'E',
    mods = 'CTRL',
    action = wezterm.action.EmitEvent 'toggle-colorscheme',
  },
}
-- Maybe I should try fix this instead of suppressing this warning.
config.warn_about_missing_glyphs = false


-- config.window_background_image = "/home/ritiek/Pictures/island-fantastic-coast-mountains-art.jpg"
-- config.window_background_opacity = 0.7

-- and finally, return the configuration to wezterm
return config
      '';
    };
    programs.zsh = {
      enable = true;
      profileExtra = ''
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

export EDITOR="nvim"
export VIM="$HOME/.config/nvim"
export VIMRUNTIME="/usr/share/nvim/runtime"
export BROWSER="google-chrome-stable"
export LESS="--mouse --wheel-lines=3 -r"
export LESSOPEN="|$HOME/.lessfilter %s"
# Reduce lag when switching between Normal and Insert mode with Vi
# bindings in zsh
export KEYTIMEOUT=1

export OPENCV_LOG_LEVEL=ERROR

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# export JAVA_OPTS="-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee"
export GOPATH="$HOME/go"

export POWERLINE_BASH_CONTINUATION=1
export POWERLINE_BASH_SELECT=1

export ESPIDF=/opt/esp-idf

# export QT_QPA_PLATFORMTHEME="qt5ct"

# export PYENV_ROOT="$HOME/.pyenv"
# command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"

# set PATH so it includes user's private bin directories
PATH="$HOME/bin:$HOME/.local/bin:$PATH"
PATH="$HOME/go/bin:$PATH"
PATH="$HOME/.cabal/bin:$PATH"
PATH="$HOME/.rbenv/bin:$PATH"
PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
PATH="$HOME/.rbenv/bin:$PATH"
PATH="$HOME/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$HOME/bin/gyb:$PATH"
PATH="$HOME/.cargo/bin:$PATH"
PATH="$HOME/Android/flutter/bin:$PATH"
PATH="$HOME/.gem/ruby/2.5.0/bin:$PATH"
PATH="/snap/bin:$PATH"
export PATH

alias cp="cp --reflink=auto --sparse=always"

eval $(keychain --eval --quiet --noask)
      '';
      initExtraFirst = ''
source ~/.zprofile

# Space prefix to suppress history
setopt HIST_IGNORE_SPACE

# Refresh commands-cache for tab-completion
zstyle ":completion:*:commands" rehash 1

# Set your own notification threshold
bgnotify_threshold=5

function bgnotify_formatted {
  ## $1=exit_status, $2=command, $3=elapsed_time
  [ $1 -eq 0 ] && title="Succeeded" || title="Failed"
  bgnotify "$title in $3s" "$2";
}
      '';
      initExtraBeforeCompInit = ''
# Allow symlinks
ZSH_DISABLE_COMPFIX=true
      '';
      initExtra = ''
# ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=59'

# Make Enter key on the numpad work as Return key
bindkey '^[OM' accept-line

# Reverse search like in Bash
bindkey '^R' history-incremental-search-backward

bindkey '^[[Z' reverse-menu-complete
# Navigate to previous selection with shift+tab
# when using tab completition for navigation

# zsh-autosuggetsions maps
## map autosuggest-accept to ctrl+/
bindkey '^_' autosuggest-accept
#bindkey '^M' autosuggest-execute

# Enable Vi bindings
bindkey -v

autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd ' ' edit-command-line
bindkey "^?" backward-delete-char
      '';
      envExtra = ''
      '';
      shellAliases = {
        ll = "ls -l";
        update = "sudo nixos-rebuild switch";
	# Check if xclip is even being used in hyprland
	xclip = "xclip -selection clipboard";
      };
      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
	  # File path is $src + $file
          src = ./.;
          file = "p10k.zsh";
        }
      ];
      enableAutosuggestions = true;
      enableCompletion = true;
      enableVteIntegration = true;
      history = {
        save = 10000;
	size = 10000;
	expireDuplicatesFirst = true;
	extended = true;
      };
      oh-my-zsh = {
        enable = true;
	plugins = [
	  "bgnotify"
	  "colored-man-pages"
	  "command-not-found"
	];
      };
      syntaxHighlighting = {
        enable = true;
	styles = {
	  path = "fg=cyan";
	  path_prefix = "fg=magenta";
	};
	highlighters = [
	  "main"
	  "brackets"
	];
      };
    };
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
