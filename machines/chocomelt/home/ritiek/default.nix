{ pkgs, inputs, ... }:
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
    # opencode.nix declares sops.secrets."lightpanda_cdp.token", which isn't
    # present in any per-host secrets.yaml yet (pre-existing repo issue -
    # radrubble's own home-manager build currently fails the same way).
    # Re-enable once that secret is added to machines/chocomelt/home/ritiek/secrets.yaml.
    # ./../../../../modules/home/opencode.nix
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
    command-not-found.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
  };
}
