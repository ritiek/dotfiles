{ config, ... }:
{
  sops = {
    defaultSopsFile = ./../machines/${config.networking.hostName}/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
