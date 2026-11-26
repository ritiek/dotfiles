{ ... }:
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
    trusted-users = [
      "nixos"
      "ritiek"
      "rnixbld"
    ];
    # Fallback to building from source when cache server is not accessible.
    fallback = true;
    connect-timeout = 3;
    # Let remote builders fetch derivation dependencies from cache configured
    # on remote builders.
    builders-use-substitutes = true;
    sandbox = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
    persistent = true;
  };

  # Distrust roots of the leaked eMudhra intermediate CA keys.
  # https://ghuntley.com/patch/
  # TODO: Remove this when things have cooled down a bit.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    # "emSign ECC Root CA - G3" was dropped upstream in nss-cacert 3.131.1.
  ];

  # Configure nix-daemon socket for remote builder access
  # systemd.tmpfiles.rules = [
  #   "d /nix/var/nix/daemon-socket 0755 root nixbld - -"
  #   "d /nix/var/nix/daemon-socket/socket 0660 root nixbld - -"
  # ];
}
