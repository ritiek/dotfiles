{ pkgs, inputs, ... }:
{
  imports = [
    ./nixconf/zsh
    ./nixconf/git
    ./nixconf/neovim
    ./nixconf/zellij.nix
    ./nixconf/btop.nix
  ];
  home = {
    stateVersion = "24.05";
    packages = with pkgs; [
      any-nix-shell

      unzip
      unrar-wrapper
      sd
      diskonaut

      iptables
      nmap
      dig
      cryptsetup
      openssl
      sops

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
  };
}
