{ config, ... }:
{
  sops = {
    defaultSopsFile = 
      if config.networking.hostName == "mishy-usb" 
      then ./../machines/mishy/secrets.yaml
      else ./../machines/${config.networking.hostName}/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
