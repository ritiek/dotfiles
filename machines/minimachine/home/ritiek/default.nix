{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule

    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
  ];
  home = {
    stateVersion = "25.05";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      any-nix-shell
      psmisc
      moreutils

      unzip
      unrar-wrapper
      sd
      compsize
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
