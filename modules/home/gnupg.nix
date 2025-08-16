{ pkgs, ... }:
{
  services.gpg-agent = {
    enable = true;
    # enableExtraSocket = true;
    enableSshSupport = true;
    sshKeys = [
      "5093E5BC80A747932DDBE3400EF3B45E3546EDCE"
    ];
    # pinentryPackage = pkgs.pinentry-curses;
    pinentryPackage = pkgs.pinentry-gnome3;
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
