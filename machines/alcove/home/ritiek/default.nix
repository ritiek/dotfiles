{ pkgs, inputs, lib, ... }:
{
  imports = [
    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    # ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
    ./../../../../modules/home/opencode
    ./../../../../modules/home/direnv.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: _prev: {
      unstable = import inputs.unstable {
        inherit (final) system;
        config.allowUnfree = true;
      };
    })
  ];

  home = {
    stateVersion = "24.11";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      any-nix-shell
      psmisc
      moreutils
      file
      nix-output-monitor

      unzip
      unrar-wrapper
      sd
      compsize
      lshw
      gdu

      iptables
      nmap
      dig
      cryptsetup
      openssl
      deploy-rs

      miniserve
      bore-cli
      iperf
    ];
  };

  programs = {
    # OpenCode V2 trial. The package only ships `opencode2`; also expose it as
    # `opencode` for opencode.nvim and muscle memory.
    opencode.package = let
      oc2 = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
    in lib.mkForce (pkgs.symlinkJoin {
      name = "opencode-${oc2.version}";
      paths = [ oc2 ];
      postBuild = "ln -s opencode2 $out/bin/opencode";
      meta.mainProgram = "opencode";
    });
    command-not-found.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
  };
}
