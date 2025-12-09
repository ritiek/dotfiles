{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule

    # ./../../../../home/gnupg.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    # ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
  ];
  home = {
    stateVersion = "24.11";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      any-nix-shell

      unzip
      unrar-wrapper
      sd
      # diskonaut
      compsize

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
