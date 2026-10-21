{ config, lib, pkgs, ... }:
let
  cache = import ../substituters.nix;
  # On-demand remote builds: `<name> <any nix command>` sends builds to the
  # nixbuild.net account that `secret` (an SSH key) is registered with.
  # Only installed on hosts that declare the secret.
  # Last machines field is eu.nixbuild.net's base64 host key, so no known_hosts entry is needed.
  mkNixbuild = name: secret:
    lib.optional (config ? sops && config.sops.secrets ? ${secret})
      (pkgs.writeShellScriptBin name ''
        export NIX_CONFIG="builders = @${pkgs.writeText "${name}-machines" ''
          ssh-ng://eu.nixbuild.net x86_64-linux,aarch64-linux ${config.sops.secrets.${secret}.path} 100 1 benchmark,big-parallel - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSVBJUUNaYzU0cG9KOHZxYXdkOFRyYU5yeVFlSm52SDFlTHBJRGdiaXF5bU0=
        ''}
        ''${NIX_CONFIG:-}"
        exec "$@"
      '');
in
{
  environment.systemPackages =
    mkNixbuild "nixbuild" "rnixbld.id_ed25519"
    ++ mkNixbuild "nixbuild2" "nixbuild2.id_ed25519"
    ++ mkNixbuild "nixbuild3" "nixbuild3.id_ed25519";

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
    "emSign ECC Root CA - G3"
  ];

  # Configure nix-daemon socket for remote builder access
  # systemd.tmpfiles.rules = [
  #   "d /nix/var/nix/daemon-socket 0755 root nixbld - -"
  #   "d /nix/var/nix/daemon-socket/socket 0660 root nixbld - -"
  # ];
}
