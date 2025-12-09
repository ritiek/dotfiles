{ config, pkgs, hostName, ... }:
{
  imports = [
    ./gnupg.nix
  ];

  sops = {
    defaultSopsFile = 
      if hostName == "mishy-usb" 
      then ./../../machines/mishy/home/${config.home.username}/secrets.yaml
      else ./../../machines/${hostName}/home/${config.home.username}/secrets.yaml;
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/sops.id_ed25519" ];
  };

  home.packages = with pkgs; [
    sops
    ssh-to-age
    age-plugin-fido2-hmac
  ];
}
