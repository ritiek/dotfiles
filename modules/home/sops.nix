{ config, pkgs, hostName, ... }:
{
  imports = [
    ./gnupg.nix
  ];

  sops = {
    # Image/installer variants (different hostName, same secrets) reuse their
    # base host's secrets file rather than a nonexistent per-variant directory.
    defaultSopsFile =
      let
        baseHost =
          if hostName == "mishy-usb" then "mishy"
          else if hostName == "pilab-sd" || hostName == "pilab-minimal-sd" then "pilab"
          else hostName;
      in
      ./../../machines/${baseHost}/home/${config.home.username}/secrets.yaml;
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/sops.id_ed25519" ];
  };

  home.packages = with pkgs; [
    sops
    ssh-to-age
    age-plugin-fido2-hmac
    gettext
  ];
}
