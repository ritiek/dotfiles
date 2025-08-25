{
  description = "NixOS flake for my dotfiles";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # local.url = "git+file:///home/ritiek/Downloads/nixpkgs";
    # local.url = "github:ritiek/nixpkgs/init-piano-rs";
    # ghostty = {
    #   url = "github:ghostty-org/ghostty";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # habitica-nix.url = "git+file:///home/ritiek/Downloads/habitica-nix";
    # habitica-nix.url = "github:kira-bruneau/nur-packages";
    # shabitica-nix = {
    #   # url = "github:lomenzel/shabitica";
    #   url = "git+file:///home/ritiek/Downloads/shabitica";
    #   # inputs.nixpkgs.follows = "nixpkgs";
    # };
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lib-aggregate.follows = "lib-aggregate";
    };

    lib-aggregate = {
      url = "github:nix-community/lib-aggregate";
      inputs.flake-utils.follows = "flake-utils";
    };

    pi400kb-nix = {
      # url = "git+file:///home/ritiek/pi400kb?submodules=1";
      url = "git+https://github.com/ritiek/pi400kb?ref=main&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-hardware.follows = "nixos-hardware";
    };

    # nixgl = {
    #   url = "github:nix-community/nixGL";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.flake-utils.follows = "flake-utils";
    # };

    home-manager = {
      url = "github:nix-community/home-manager";
      # Using my patched home-manager to let root install systemd user services.
      # url = "github:ritiek/home-manager";

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

    # wezterm = {
    #   url = "github:wez/wezterm/main?dir=nix";
    #   # Commenting out as compilation fails (as of 10th Oct, 2024).
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    systems.url = "github:nix-systems/default";

    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
      inputs.hyprlang.follows = "hyprlang";
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
      inputs.systems.follows = "systems";
    };

    headplane = {
      url = "github:tale/headplane";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    hyprutils = {
      url = "github:hyprwm/hyprutils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    hyprlang = {
      url = "github:hyprwm/hyprlang";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprutils.follows = "hyprutils";
    };

    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprland.follows = "hyprland";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    raspberry-pi-nix = {
      url = "github:nix-community/raspberry-pi-nix";
      # XXX: Above to have gone into read-only mode. Here
      # seems a better maintained fork for the moment in case.
      # url = "github:cmyk/raspberry-pi-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rockchip = {
      url = "github:nabam/nixos-rockchip";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, ... }@inputs:
  let
    cache = import ./substituters.nix;
  in {
    nixConfig = {
      extra-substituters = cache.substituters;
      extra-trusted-public-keys = cache.trusted-public-keys;
    };

    nixosConfigurations.mishy = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/mishy
        ./machines/mishy/boot.nix
        ./machines/mishy/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
    };

    homeConfigurations."ritiek@mishy" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        # config.allowUnfree = true;
      };
      modules = [
        ./machines/mishy/home/ritiek
        { _module.args.hostName = "mishy"; }
      ];
      extraSpecialArgs = { inherit inputs; };
    };

    nixosConfigurations.pilab = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./machines/pilab
        ./machines/pilab/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
    };

    homeConfigurations."ritiek@pilab" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "aarch64-linux";
        # config.allowUnfree = true;
      };
      modules = [
        ./machines/pilab/home/ritiek
        { _module.args.hostName = "pilab"; }
      ];
      extraSpecialArgs = { inherit inputs; };
    };

    homeConfigurations."immi@pilab" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "aarch64-linux";
        # config.allowUnfree = true;
      };
      modules = [
        ./machines/pilab/home/immi
        { _module.args.hostName = "pilab"; }
      ];
      extraSpecialArgs = { inherit inputs; };
    };
    nixosConfigurations.clawsiecats-minimal = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats/minimal.nix
        ./machines/clawsiecats/hw-config/gpt.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.clawsiecats = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats
        ./machines/clawsiecats/hw-config/mbr.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.clawsiecats-luks = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/clawsiecats
        ./machines/clawsiecats/hw-config/gpt-luks.nix
      ];
      specialArgs = { inherit inputs; };
    };

    homeConfigurations."ritiek@clawsiecats" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        # config.allowUnfree = true;
      };
      modules = [
        ./machines/clawsiecats/home/ritiek
        { _module.args.hostName = "clawsiecats"; }
      ];
      extraSpecialArgs = { inherit inputs; };
    };

    nixosConfigurations.keyberry = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./machines/keyberry
        ./machines/keyberry/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
    };

    homeConfigurations."ritiek@keyberry" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = "aarch64-linux";
        # config.allowUnfree = true;
      };
      modules = [
        ./machines/keyberry/home/ritiek
        { _module.args.hostName = "keyberry"; }
      ];
      extraSpecialArgs = { inherit inputs; };
    };

    nixosConfigurations.zerostash = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./machines/zerostash
        ./machines/zerostash/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.radrubble = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./machines/radrubble
        ./machines/radrubble/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.mangoshake = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./machines/mangoshake
        ./machines/mangoshake/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
    };


    deploy.nodes.mishy = {
      hostname = "mishy.lion-zebra.ts.net";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.mishy;
      };
      sshUser = "ritiek";
    };

    deploy.nodes.pilab = {
      hostname = "pilab.lion-zebra.ts.net";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.pilab;
      };
      sshUser = "ritiek";
    };

    deploy.nodes.clawsiecats = {
      hostname = "clawsiecats.lol";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.clawsiecats;
      };
      sshUser = "ritiek";
    };

    deploy.nodes.keyberry = {
      hostname = "keyberry.lion-zebra.ts.net";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.keyberry;
      };
      sshUser = "ritiek";
    };

    deploy.nodes.zerostash = {
      hostname = "zerostash.lion-zebra.ts.net";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.zerostash;
      };
      sshUser = "ritiek";
    };

    deploy.nodes.radrubble = {
      hostname = "radrubble.lion-zebra.ts.net";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.radrubble;
      };
      sshUser = "ritiek";
    };

    deploy.nodes.mangoshake = {
      hostname = "mangoshake.lion-zebra.ts.net";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.mangoshake;
      };
      sshUser = "root";
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;


    minimal-iso = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      specialArgs = { inherit inputs; };
      format = "iso";
    };

    minimal-install-iso = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      specialArgs = { inherit inputs; };
      format = "install-iso";
    };

    minimal-qcow-efi = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      specialArgs = { inherit inputs; };
      format = "qcow-efi";
    };

    minimal-raw-efi = inputs.nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./generators/minimal.nix ];
      specialArgs = { inherit inputs; };
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

    pilab-sd = self.nixosConfigurations.pilab.config.system.build.sdImage;

    keyberry-sd = inputs.nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      modules = [
        ./machines/keyberry
        ./machines/keyberry/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
      format = "sd-aarch64";
    };

    zerostash-sd = inputs.nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      modules = [
        ./machines/zerostash
        ./machines/zerostash/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
      format = "sd-aarch64";
    };

    radrubble-sd = self.nixosConfigurations.radrubble.config.system.build.sdImage;

    # NOTE: Reason for commenting this out:
    # For some reason 'sd-aarch64-installer' assigns the value of
    # `users.users.root.initialHashedPassword`, which makes the
    # machine unloggable.
    # keyberry-sd-installer = inputs.nixos-generators.nixosGenerate {
    #   system = "aarch64-linux";
    #   modules = [ ./machines/keyberry inputs.nixos-hardware.nixosModules.raspberry-pi-4 ];
    #   specialArgs = { inherit inputs; };
    #   format = "sd-aarch64-installer";
    # };

    mangoshake-sd = inputs.nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      modules = [
        ./machines/mangoshake
        ./machines/mangoshake/hw-config.nix
      ];
      specialArgs = { inherit inputs; };
      format = "sd-aarch64";
    };
  };
}
