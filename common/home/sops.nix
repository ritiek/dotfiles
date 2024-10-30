{ inputs, config, osConfig, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule
  ];

  sops = {
    defaultSopsFile = ./../../machines/${osConfig.networking.hostName}/home/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
