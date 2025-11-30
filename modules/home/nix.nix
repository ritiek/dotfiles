{ config, ... }:
{
  sops.secrets."github.token" = {};

  sops.templates."nix.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder."github.token"}
    '';
    path = ".config/nix/nix.conf";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
    persistent = true;
  };
}
