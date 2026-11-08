{ pkgs, lib, ... }:
{
  # At boot, importGpgKeys runs before /run/user/$UID exists, so gpg spawns
  # keyboxd/gpg-agent with sockets in ~/.gnupg. That keyboxd holds
  # pubring.db.lock forever and every later gpg (sops) hangs waiting on it.
  # Only kill in that case so a `switch` mid-session keeps the real agent.
  home.activation.killBootGpgDaemons = lib.hm.dag.entryAfter [ "importGpgKeys" ] ''
    if [ ! -d "/run/user/$(id -u)" ]; then
      run ${pkgs.gnupg}/bin/gpgconf --kill keyboxd gpg-agent
    fi
  '';

  services.gpg-agent = {
    enable = true;
    # enableExtraSocket = true;
    enableSshSupport = false;
    sshKeys = [
      "5093E5BC80A747932DDBE3400EF3B45E3546EDCE"
    ];
    # pinentryPackage = pkgs.pinentry-curses;
    pinentry.package = pkgs.pinentry-gnome3;
  };
  programs.gpg = {
    enable = true;
    publicKeys = [
      {
        # Ritiek Malhotra <ritiekmalhotra123@gmail.com>
        source = (pkgs.fetchurl {
          url = "https://keys.openpgp.org/vks/v1/by-fingerprint/66FF60997B04845FF4C0CB4FEB6FC9F9FC964257";
          sha256 = "sha256-FoZfnwrRID7CRa7FYBd7LUlA7E1IfaJEMzyNJqoi+s4=";
        });
        trust = 5;
      }
    ];
  };
}
