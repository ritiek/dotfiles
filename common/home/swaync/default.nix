{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];
  home.file.swaync = {
    source =  ./swaync;
    target = "${config.home.homeDirectory}/.config/swaync";
    # Doesn't work.
    # onChange = "sh -c '${pkgs.swaynotificationcenter}/bin/swaync-client --reload-config'";
  };
  # options.services.swaync = {
  #   enable = true;
  #   settings = builtins.fromJSON (builtins.readFile ../chezmoi/dot_config/swaync/config.json);
  #   style = builtins.readFile ../chezmoi/dot_config/swaync/style.css;
  # };
}
