{ pkgs, inputs, ... }:
{
  imports = [
    ./nixconf/zsh
    ./nixconf/git
    ./nixconf/neovim
    ./nixconf/zellij.nix
    ./nixconf/btop.nix
  ];
  programs = {
    command-not-found.enable = true;
  };
  home = {
    /* The home.stateVersion option does not have a default and must be set */
    stateVersion = "24.05";
    packages = with pkgs; [
      unzip
      unrar-wrapper
      sd
      lxqt.lxqt-policykit
      any-nix-shell
      diskonaut
      cryptsetup
      openssl

      miniserve
      bore-cli

      nmap
      dig
    ];
  };

  programs = {
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
  };
}
