{ config, lib, pkgs, ... }:
let
  cache = import ../substituters.nix;
  hasRnixbldKey = config ? sops && config.sops.secrets ? "rnixbld.id_ed25519";
  # Last field is eu.nixbuild.net's base64 host key, so no known_hosts entry is needed.
  nixbuildMachines = pkgs.writeText "nixbuild-machines" ''
    ssh-ng://eu.nixbuild.net x86_64-linux,aarch64-linux ${config.sops.secrets."rnixbld.id_ed25519".path} 100 1 benchmark,big-parallel - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSVBJUUNaYzU0cG9KOHZxYXdkOFRyYU5yeVFlSm52SDFlTHBJRGdiaXF5bU0=
  '';
in
{
  # On-demand remote builds: `nixbuild <any nix command>` sends builds to nixbuild.net.
  environment.systemPackages = lib.optionals hasRnixbldKey [
    (pkgs.writeShellScriptBin "nixbuild" ''
      export NIX_CONFIG="builders = @${nixbuildMachines}
      ''${NIX_CONFIG:-}"
      exec "$@"
    '')
  ];

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

  # Configure nix-daemon socket for remote builder access
  # systemd.tmpfiles.rules = [
  #   "d /nix/var/nix/daemon-socket 0755 root nixbld - -"
  #   "d /nix/var/nix/daemon-socket/socket 0660 root nixbld - -"
  # ];
}
