{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # unstable.meshtastic
    # meshtastic
    python3Packages.meshtastic
    # unstable.contact
  ];
}
