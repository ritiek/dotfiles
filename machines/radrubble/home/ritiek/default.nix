{ pkgs, inputs, ... }:
{
  imports = [
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/btop.nix
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
      sops
      deploy-rs

      miniserve
      bore-cli
    ];
  };
  
  programs = {
    command-not-found.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
    claude-code.enable = true;
  };
}
