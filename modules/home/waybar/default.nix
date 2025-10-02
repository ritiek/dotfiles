{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = builtins.fromJSON (builtins.readFile ./config);
    };
    style = builtins.readFile ./style.css;
  };
  
  # Create a script to switch waybar configs based on compositor
  home.packages = with pkgs; [
    (writeShellScriptBin "waybar-launch" ''
      echo "Starting waybar with default configuration"  
      waybar &
    '')
  ];
  
  # Add the niri config file
  xdg.configFile."waybar/config-niri".text = builtins.toJSON {
    layer = "top";
    output = ["eDP-1" "HDMI-A-1"];
    position = "bottom";
    spacing = 0;
    height = 34;
    modules-left = [
        "custom/logo"
        "custom/workspaces"
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
    "custom/workspaces" = {
        exec = "niri msg --json workspaces | jq -r 'map(select(.output != null)) | group_by(.output) | map(sort_by(.idx)) | flatten | map(if .is_active then \"󱓻\" else (.name // (.idx | tostring)) end) | join(\"   \")'";
        format = "{}";
        interval = 1;
        tooltip = false;
        on-click = "echo"; # Disable clicking for now since it's complex with multiple outputs
    };
    "niri/window" = {
        max-length = 200;
        separate-outputs = true;
    };
    tray = {
        spacing = 10;
    };
    clock = {
        tooltip-format = "<tt>{calendar}</tt>";
        format-alt = "  {:%a, %d %b %Y}";
        format = "  {:%I:%M %p}";
    };
    battery = {
        format = "{capacity}% {icon}";
        format-icons = {
            charging = [
                "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅"
            ];
            default = [
                "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"
            ];
        };
        format-full = "Charged ";
        interval = 5;
        states = {
            warning = 20;
            critical = 10;
        };
        tooltip = false;
    };
  };
}
