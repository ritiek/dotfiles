{ config, ... }:
{
  sops.secrets."nix.conf".path = "${config.home.homeDirectory}/.config/nix/nix.conf";
}
