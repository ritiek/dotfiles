{ pkgs, inputs, config, ... }:
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
  home-manager.users.ritiek = {
    imports = [
      # ./../../../../home/gnupg.nix
      ./../../../../modules/home/zsh
      ./../../../../modules/home/git
      ./../../../../modules/home/neovim
      ./../../../../modules/home/zellij.nix
      ./../../../../modules/home/btop.nix
    ];
    nixpkgs.config.allowUnfree = true;
    home = {
      stateVersion = "24.11";
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
  };
}
