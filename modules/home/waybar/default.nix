{ pkgs, lib, config, ... }:
let
  # Check if niri is enabled by looking for niri in the environment
  isNiriEnabled = builtins.any (pkg: pkg.pname or "" == "niri") config.home.packages;
  
  # Base waybar config
  baseConfig = builtins.fromJSON (builtins.readFile ./config);
  
  # Conditionally configure waybar based on the window manager
  waybarConfig = baseConfig // {
    modules-left = 
      if isNiriEnabled then
        # When niri is enabled, remove hyprland-specific modules and keep niri ones
        builtins.filter (module: module != "hyprland/workspaces") baseConfig.modules-left
      else
        # When niri is not enabled, remove niri-specific modules and keep hyprland ones  
        builtins.filter (module: module != "niri/workspaces") baseConfig.modules-left;
  } // lib.optionalAttrs (!isNiriEnabled) {
    # Remove niri-specific module configurations when niri is disabled
    "niri/workspaces" = null;
  };
in
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = waybarConfig;
    };
    style = builtins.readFile ./style.css;
  };
}
