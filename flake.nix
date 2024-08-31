{
  # TODO: Should I have git track my hardware-configuration.nix? Or do have it generate dynamically
  # using `sudo nixos-generate-config`?
  description = "NixOS flake for my dotfiles";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nur.url = "github:nix-community/NUR";
    stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # local.url = "git+file:///home/ritiek/Downloads/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm-flake = {
      url = "github:wez/wezterm/main?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
  };

  # outputs = { self, nixpkgs, nur, stable, unstable, local, home-manager, rose-pine-hyprcursor, ... }@inputs:
  outputs = { self, nixpkgs, nur, stable, unstable, home-manager, rose-pine-hyprcursor, ... }@inputs:
    {
    # Please replace my-nixos with your hostname
    nixosConfigurations.nixin = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix

        {
          nixpkgs.overlays = [
            nur.overlay
            (final: _prev: {
              stable = import stable {
                inherit (final) system;
                config.allowUnfree = true;
              };
            })
            (final: _prev: {
              unstable = import unstable {
                inherit (final) system;
                config.allowUnfree = true;
              };
            })
            # (final: _prev: {
            #   local = import local {
            #     inherit (final) system;
            #     config.allowUnfree = true;
            #   };
            # })
          ];
        }

        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
          };
          # home-manager.extraSpecialArgs = {
          #   stable = import stable {
          #     inherit system;
          #     config.allowUnfree = true;
          #   };
          # };
          home-manager.users.ritiek = import ./home.nix;
          environment.pathsToLink = [
            "/share/zsh"
            "/share/xdg-desktop-portal"
            "/share/applications"
          ];
        }
      ];
      specialArgs = {
        inherit inputs;
      };
    };
  };
}
