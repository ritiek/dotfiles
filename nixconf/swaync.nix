{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];
  home.file.swaync = {
    source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/swaync;
    target = "${config.home.homeDirectory}/.config/swaync";
    # Doesn't work.
    # onChange = "sh -c '${pkgs.swaynotificationcenter}/bin/swaync-client --reload-config'";
  };
  # options.services.swaync = {
  #   enable = true;
  #   settings = builtins.fromJSON (builtins.readFile /etc/nixos/chezmoi/dot_config/swaync/config.json);
  #   style = builtins.readFile /etc/nixos/chezmoi/dot_config/swaync/style.css;
  # };
}
