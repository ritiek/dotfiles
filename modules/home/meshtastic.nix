{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # unstable.meshtastic
    # meshtastic
    python313Packages.meshtastic
    # python313Packages.meshtastic
    # unstable.contact
  ];
}
