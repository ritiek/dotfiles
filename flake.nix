{
  # TODO: Should I have git track my hardware-configuration.nix? Or do have it generate dynamically
  # using `sudo nixos-generate-config`?
  description = "NixOS flake for my dotfiles";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nur.url = "github:nix-community/NUR";
    stable.url = "github:NixOS/nixpkgs/nixos-24.05";

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

  outputs = { self, nixpkgs, nur, stable, home-manager, rose-pine-hyprcursor, ... }@inputs:
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
              };
            })
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
          environment.pathsToLink = [ "/share/zsh" ];
        }
      ];
      specialArgs = {
        inherit inputs;
      };
    };
  };
}
