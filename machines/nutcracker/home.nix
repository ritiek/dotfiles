{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };
  };

  environment.pathsToLink = [
    "/share/zsh"
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  home-manager.users.root = {
    imports = [
      ./../../common/home/zsh
      ./../../common/home/git
      ./../../common/home/neovim
      ./../../common/home/zellij.nix
      ./../../common/home/btop.nix
    ];
    home = {
      stateVersion = "24.11";
      packages = with pkgs; [
        wifite2
      ];
    };
    programs.zsh.shellAliases = {
      # TODO: We should auto-start this in a Zellij session. And maybe link some kind of
      # message broker or IM for PNs related to updates.
      wifite-preconfig = ''
        wifite \
          -i $(ls /sys/class/net | grep -vE '^(lo|tailscale0|wlan0)$' | head -n 1) \
          -E $(iwgetid -r) \
          --wpa \
          --no-wps \
          --skip-crack \
          --no-pmkid \
          --showb \
          --allbands \
          --pillage 120 \
          --wpat 99999 \
          --wpadt 90 \
          --num-deauths 10 \
          --hs-dir handshakes

          # --clients-only
        '';
    };
  };
}
