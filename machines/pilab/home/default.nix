{ inputs, pkgs, config, ... }:
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
  # systemd.tmpfiles.settings."05-home-manager"."/home/ritiek/.config/home-manager/home.nix" = {
  #   "C+" = {
  #     mode = "0644";
  #     user = "ritiek";
  #     argument = "/etc/nixos/machines/pilab/home/ritiek/secrets.yaml";
  #   };
  # };
  environment.pathsToLink = [
    "/share/zsh"
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      # inherit inputs;
      hostName = config.networking.hostName;
    };

    users.ritiek = {
      imports = [
        ./ritiek/home.nix
        inputs.sops-nix.homeManagerModule
      ];
    };

    # users.immi = import ./immi

    users.root = {
      imports = [
        ./../../../modules/home/zsh
        ./../../../modules/home/neovim
      ];
      home.stateVersion = "24.11";
    };
  };
}
