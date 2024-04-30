{ pkgs, config, ... }:
{
  home.file.swaync = {
    source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/swaync;
    target = "${config.home.homeDirectory}/.config/swaync";
  };
}
