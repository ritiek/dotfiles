{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  environment.pathsToLink = [
    "/share/zsh"
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  systemd.tmpfiles.settings."10-ssh"."/home/ritiek/.ssh/sops.id_ed25519" = {
    "C+" = {
      mode = "0600";
      user = "ritiek";
      argument = "/etc/ssh/ssh_host_ed25519_key";
    };
  };

  home-manager = {
    # useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
    };

    users.ritiek = {
      imports = [
        ./ritiek
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
