{ inputs, config, osConfig, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule
  ];

  sops = {
    defaultSopsFile = ./../../machines/${osConfig.networking.hostName}/home/secrets.yaml;
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/sops.id_ed25519" ];
  };
}
