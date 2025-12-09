{ pkgs, inputs, ... }:
{
  imports = [
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    # ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
    ./../../../../modules/home/opencode.nix
    ./../../../../modules/home/direnv.nix
  ];
  
  nixpkgs.config.allowUnfree = true;
  
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
      lshw

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
