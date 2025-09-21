{ config, ... }:
{
  # TODO: Commenting this out for now as my GitHub token expired.
  #       Generate a new one and uncomment this.
  # sops.secrets."nix.conf".path = "${config.home.homeDirectory}/.config/nix/nix.conf";
}
