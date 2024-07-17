{
  # TODO: Should I have git track my hardware-configuration.nix? Or do have it generate dynamically
  # using `sudo nixos-generate-config`?
  description = "NixOS flake for my dotfiles";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    # ritiek.url = "github:ritiek/nur-packages/hide-placeholder-for-spotify-advert-banner";
    # stable.url = "github:NixOS/nixpkgs";
    # v23_11.url = "github:NixOS/nixpkgs/nixos-23.11";
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";

    home-manager = {
      url = "github:nix-community/home-manager";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nur, home-manager, rose-pine-hyprcursor, ... }@inputs: {
    # Please replace my-nixos with your hostname
    nixosConfigurations.nixin = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix

        { nixpkgs.overlays = [ nur.overlay ]; }

        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.ritiek = import ./home.nix;
          # home-manager.users.ritiek = import ./home.nix {
          #   pkgs = import nixpkgs;
          #   inherit inputs;
          # };
          environment.pathsToLink = [ "/share/zsh" ];
        }
      ];
      specialArgs = { inherit inputs; };
    };
  };
}
