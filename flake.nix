{
  description = "NixOS flake for my dotfiles";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nur.url = "github:nix-community/NUR";
    # stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # local.url = "git+file:///home/ritiek/Downloads/nixpkgs";
    # local.url = "github:ritiek/nixpkgs/init-piano-rs";

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
    # wezterm-flake.url = "github:wez/wezterm/main?dir=nix";
    wezterm-flake = {
      url = "github:wez/wezterm/main?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprgrass = {
       url = "github:horriblename/hyprgrass";
       inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { self, ... }@inputs: {
    nixosConfigurations.mishy = inputs.nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/mishy
        ./machines/mishy/boot.nix
        ./machines/mishy/hardware-configuration.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.clawsiecats-minimal = inputs.nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats/minimal.nix
        ./machines/clawsiecats/hw-config/gpt.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.clawsiecats = inputs.nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats
        ./machines/clawsiecats/hw-config/mbr.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.clawsiecats-luks = inputs.nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats
        ./machines/clawsiecats/hw-config/gpt-luks.nix
      ];
      specialArgs = { inherit inputs; };
    };


    deploy.nodes.clawsiecats = {
      hostname = "clawsiecats.omg.lol";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.clawsiecats;
      };
      sshUser = "root";
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;


    minimal-iso = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      format = "iso";
    };

    minimal-install-iso = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      format = "install-iso";
    };

    minimal-qcow-efi = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      format = "qcow-efi";
    };

    minimal-raw-efi = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      format = "raw-efi";
    };

    mishy-iso = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./machines/mishy ];
      specialArgs = { inherit inputs; };
      format = "iso";
    };

    mishy-install-iso = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./machines/mishy ];
      specialArgs = { inherit inputs; };
      format = "install-iso";
    };

    mishy-raw-efi = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./machines/mishy ];
      specialArgs = { inherit inputs; };
      format = "raw-efi";
    };
  };
}
