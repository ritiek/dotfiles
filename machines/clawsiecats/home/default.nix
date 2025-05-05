{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  environment.pathsToLink = [
    "/share/zsh"
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  systemd.tmpfiles.settings."10-home" = {
    "/nix/persist/home/ritiek".d = {
      mode = "0700";
      user = "ritiek";
    };
  };
  systemd.tmpfiles.settings."20-ssh" = {
    "/nix/persist/home/ritiek/.ssh".d = {
      mode = "0700";
      user = "ritiek";
    };
  };
  systemd.tmpfiles.settings."30-sops-key" = {
    "/nix/persist/home/ritiek/.ssh/sops.id_ed25519"."C+" = {
      mode = "0600";
      user = "ritiek";
      argument = "/etc/ssh/ssh_host_ed25519_key";
    };
  };

  # Commenting out as this doesn't look to help with directory creation.
  # environment.persistence."/nix/persist/home/ritiek" = {
  #   users.ritiek = {
  #     directories = [ ];
  #     files = [ ];
  #   };
  # };

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
