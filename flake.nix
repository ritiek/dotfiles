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

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    hyprgrass = {
       url = "github:horriblename/hyprgrass";
       inputs.hyprland.follows = "hyprland";
    };
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
    nixos-generators,
    ...
  }@inputs:
    {
    nixosConfigurations.mishy = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/mishy

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
            users.ritiek = import ./machines/mishy/home;
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

        # ./machines/clawsiecats/hw-config/mbr.nix
        ./machines/clawsiecats/hw-config/gpt.nix
        # ./machines/clawsiecats/hw-config/gpt-luks.nix

        impermanence.nixosModules.impermanence
        disko.nixosModules.disko
      ];
    };

    nixosConfigurations.clawsiecats = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats

        ./machines/clawsiecats/hw-config/mbr.nix
        # ./machines/clawsiecats/hw-config/gpt.nix

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
        # impermanence.nixosModules.home-manager.impermanence

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

        # ./machines/clawsiecats/hw-config/mbr-luks.nix
        ./machines/clawsiecats/hw-config/gpt-luks.nix

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

    minimal-iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      format = "iso";
    };

    minimal-install-iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      format = "install-iso";
    };
  };
}
