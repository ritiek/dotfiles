{ config, ... }:
{
  sops.secrets."nix_config_overrides".path = "${config.home.homeDirectory}/.config/nix/nix.conf";
}
