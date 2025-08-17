{ config, ... }:
let
  cache = import ../substituters.nix;
in
{
  nix.settings = {
    inherit (cache)
      substituters
      trusted-public-keys;

    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "nixos" "ritiek" ];
    # Fallback to building from source when cache server is not accessible.
    fallback = true;
  };
}
