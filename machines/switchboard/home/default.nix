{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  # Without this, C+ below creates a missing ~/.ssh as root:root and HM can't link into it.
  systemd.tmpfiles.settings."10-ssh"."/home/ritiek/.ssh".d = {
    mode = "0700";
    user = "ritiek";
    group = "users";
  };
  systemd.tmpfiles.settings."10-ssh"."/home/ritiek/.ssh/sops.id_ed25519" = {
    "C+" = {
      mode = "0600";
      user = "ritiek";
      argument = "/etc/ssh/ssh_host_ed25519_key";
    };
  };

  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
    };

    users.ritiek = {
      imports = [
        ./ritiek
        inputs.sops-nix.homeManagerModule
      ];
    };

    users.root = {
      imports = [
        ./../../../modules/home/zsh
        ./../../../modules/home/neovim
      ];
      home.stateVersion = "24.11";
    };
  };
}
