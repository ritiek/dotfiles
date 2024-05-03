{ pkgs, ... }:
let
  theme = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/dracula/alacritty/master/dracula.toml";
  };
in {
  programs.alacritty = {
    enable = true;
    settings = {
      import = [
        theme
      ];
      font = {
        size = 12.2;
	normal = {
	  family = "FantasqueSansM Nerd Font Mono";
	  style = "Regular";
	};
      };
    };
  };
}
