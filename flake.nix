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
    # home-manager-stable = {
    #   url = "github:nix-community/home-manager/release-24.05";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    wezterm-flake = {
      url = "github:wez/wezterm/main?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    impermanence.url = "github:nix-community/impermanence";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
  {
    self,
    nixpkgs,
    nur,
    stable,
    unstable,
    home-manager,
    rose-pine-hyprcursor,
    nix-index-database,
    sops-nix,
    impermanence,
    disko,
    deploy-rs,
    ...
  }@inputs:
    {
    nixosConfigurations.nixin = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/nixin

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
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs;
            };
            # extraSpecialArgs = {
            #   stable = import stable {
            #     inherit system;
            #     config.allowUnfree = true;
            #   };
            # };
            users.ritiek = import ./machines/nixin/home;
          };
          environment.pathsToLink = [
            "/share/zsh"
            "/share/xdg-desktop-portal"
            "/share/applications"
          ];
        }

        nix-index-database.nixosModules.nix-index {
          programs.nix-index-database.comma.enable = true;
        }
      ];
      specialArgs = {
        inherit inputs;
      };
    };

    nixosConfigurations.clawsiecats-minimal = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats/minimal.nix
        ./machines/clawsiecats/hardware-configuration.nix
        impermanence.nixosModules.impermanence
        disko.nixosModules.disko
      ];
    };

    nixosConfigurations.clawsiecats = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats
        ./machines/clawsiecats/hardware-configuration.nix

        home-manager.nixosModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs;
            };
            users.root = import ./machines/clawsiecats/home;
          };
          environment.pathsToLink = [
            "/share/zsh"
            "/share/applications"
          ];
        }

        nix-index-database.nixosModules.nix-index {
          programs.nix-index-database.comma.enable = true;
        }

        sops-nix.nixosModules.sops

        impermanence.nixosModules.impermanence

        disko.nixosModules.disko
      ];
      specialArgs = {
        inherit inputs;
      };
    };

    nixosConfigurations.clawsiecats-luks = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats
        ./machines/clawsiecats/hardware-configuration-luks.nix

        home-manager.nixosModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs;
            };
            users.root = import ./machines/clawsiecats/home;
          };
          environment.pathsToLink = [
            "/share/zsh"
            "/share/applications"
          ];
        }

        nix-index-database.nixosModules.nix-index {
          programs.nix-index-database.comma.enable = true;
        }

        sops-nix.nixosModules.sops

        impermanence.nixosModules.impermanence

        disko.nixosModules.disko
      ];
      specialArgs = {
        inherit inputs;
      };
    };
    deploy.nodes.clawsiecats = {
      hostname = "clawsiecats.omg.lol";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.clawsiecats;
      };
      sshUser = "root";
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
