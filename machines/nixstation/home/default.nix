{ config, inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  systemd.tmpfiles.settings."10-ssh"."/home/ritiek/.ssh/sops.id_ed25519" = {
    "C+" = {
      mode = "0600";
      user = "ritiek";
      argument = "/etc/ssh/ssh_host_ed25519_key";
    };
  };

  home-manager = {
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
    };
    users.ritiek.imports = [ ./ritiek ];
  };
}
