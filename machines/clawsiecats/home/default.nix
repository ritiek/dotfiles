{ pkgs, inputs, config, ... }:
{
  imports = [
    # "${inputs.impermanence}/home-manager.nix"
    inputs.impermanence.nixosModules.home-manager.impermanence
    ./zsh
    ./git
    ./neovim
    ./zellij.nix
    ./btop.nix
  ];
  home = {
    stateVersion = "24.05";
    persistence."/nix/persist/home/${config.home.username}" = {
      # enable = true;
      # hideMounts = true;
      directories = [
        ".local/share/nvim"
        ".local/state/nvim"
        ".local/cache/nvim"
      ];
      files = [
        ".zsh_history"
        ".nvim-lazy-lock.json"
      ];
      allowOther = false;
    };
    packages = with pkgs; [
      any-nix-shell

      unzip
      unrar-wrapper
      sd
      diskonaut
      compsize

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
