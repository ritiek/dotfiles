{ inputs, pkgs, config, homelabMediaPath, everythingElsePath, enableLEDs, ... }:
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
    # useGlobalPkgs = false so home-manager builds its own pkgs from inputs.nixpkgs
    # (vanilla 26.05) rather than the system pkgs which go through nixos-raspberrypi's
    # overlays (vendor kernel/firmware etc.) and may be missing packages like
    # `neovimUtils.makeVimPackageInfo`.
    useGlobalPkgs = false;
    useUserPackages = true;
    # Apply the same overlays the NixOS system pkgs has, so that `pkgs.unstable` etc.
    # are available in home-manager modules.
    sharedModules = [
      {
        nixpkgs.overlays = [
          (final: _prev: {
            unstable = import inputs.unstable {
              inherit (final) system;
              config.allowUnfree = true;
            };
          })
          # Some Python packages have timing-sensitive tests that pass upstream
          # but flake on the slow Pi 5 hardware. Disable just those tests.
          (_final: prev: {
            python312Packages = prev.python312Packages.overrideScope (_pyfinal: pyprev: {
              # python-lsp-server 1.14.0: flaky autoimport test that times out.
              python-lsp-server = pyprev.python-lsp-server.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [
                  "test_autoimport_code_actions_and_completions_for_notebook_document"
                ];
              });
            });
          })
        ];
      }
    ];
    extraSpecialArgs = {
      inherit inputs homelabMediaPath everythingElsePath enableLEDs;
      hostName = config.networking.hostName;
      yubiluksEnvPath = config.sops.secrets."yubiluks.env".path;
    };

    users.ritiek = {
      imports = [
        ./ritiek
      ];
    };

    users.immi = {
      imports = [
        ./immi
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
