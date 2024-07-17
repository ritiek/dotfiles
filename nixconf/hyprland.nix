{ pkgs, config, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    # enableNvidiaPatches = true;
    # xwayland.enable = false;
    systemd = {
      enable = true;
      variables = ["-all"];
    };
    extraConfig = builtins.readFile ../chezmoi/dot_config/hypr/hyprland.conf;
  };
  home.packages = with pkgs; [
    xdg-desktop-portal-hyprland
    hypridle
    hyprlock
    hyprpaper
    hyprpicker
    hyprcursor
  ];
  home.file = {
    hyprland = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprland;
      target = "${config.home.homeDirectory}/.config/hypr/hyprland";
    };
    hypridle = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hypridle.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hypridle.conf";
    };
    hyprlock = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprlock.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hyprlock.conf";
    };
    hyprpaper = {
      source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/hypr/hyprpaper.conf;
      target = "${config.home.homeDirectory}/.config/hypr/hyprpaper.conf";
    };
    # Now using flake.nix input instead.
    # hyprcursor = {
    #   source = (pkgs.fetchFromGitHub {
    #     owner = "ndom91";
    #     repo = "rose-pine-hyprcursor";
    #     rev = "7e0473876f0e6d2308813a78fe84a6c6430b112b";
    #     hash = "sha256-wLuFLI6S5DOretqJN05+kvrs8cbnZKfVLXrJ4hvI/Tg=";
    #   }) # + "/hyprcursors";
    #   target = "${config.home.homeDirectory}/.local/share/icons/rose-pine-hyprcursor";
    # };
    wallpaper = {
      source = builtins.fetchurl {
        url = "https://i.imgur.com/gtGew3r.jpg";
        sha256 = "0kjkj73szx2ahdh9kxyzy2z4alh2xz4z47fzbc9ns6mcxjwqsr1s";

        # url = "https://i.imgur.com/tjXNPpW.jpg";
      };
      target = "${config.home.homeDirectory}/Pictures/wallpaper.jpg";
      # FIXME: `onChange` isn't working right now for some reason.
      # The plan is to update wallpaper automatically if the above URL gets changed.
      onChange = ''
export HYPRLAND_INSTANCE_SIGNATURE="gIbbEr1Sh";
${pkgs.hyprland}/bin/hyprctl hyprpaper unload all;
${pkgs.hyprland}/bin/hyprctl hyprpaper preload ~/Pictures/wallpaper.jpg;
${pkgs.hyprland}/bin/hyprctl hyprpaper wallpaper eDP-1,~/Pictures/wallpaper.jpg;
'';
    };
  };
}
