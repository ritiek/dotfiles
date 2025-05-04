{ config, hostName, ... }:
{
  sops = {
    defaultSopsFile = ./../../machines/${hostName}/home/${config.home.username}/secrets.yaml;
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/sops.id_ed25519" ];
  };
}
