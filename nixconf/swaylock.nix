{ pkgs, config, ... }:
{
  # home.file.swaylock = {
  #   source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/swaylock;
  #   target = "${config.home.homeDirectory}/.config/swaylock";
  # };
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      font = "Ubuntu";

      # Commenting this out as this lets me press Enter which prompts
      # my hardware security key for touch.
      # ignore-empty-password
      screenshots = true;

      clock = true;
      timestr = "%I:%M %p";
      datestr = "%d %b, %A";

      indicator = true;
      indicator-radius = 150;
      indicator-thickness = 7;

      effect-blur = "7x5";
      effect-vignette = "0.5:0.5";

      grace = 2;
      fade-in = 0.2;

      inside-color = "00000088";

      ring-color = "bb00cc";
      ring-clear-color = "231f20D9";
      ring-caps-lock-color = "231f20D9";
      ring-ver-color = "231f20D9";
      ring-wrong-color = "231f20D9";

      line-color = "00000000";
      line-clear-color = "ffd204FF";
      line-caps-lock-color = "009ddcFF";
      line-ver-color = "d9d8d8FF";
      line-wrong-color = "ee2e24FF";

      text-clear-color = "ffd20400";
      text-ver-color = "d9d8d800";
      text-wrong-color = "ee2e2400";

      separator-color = "00000000";

      key-hl-color = "880033";
      bs-hl-color = "ee2e24FF";
      caps-lock-key-hl-color = "ffd204FF";
      caps-lock-bs-hl-color = "ee2e24FF";

      disable-caps-lock-text = true;
      text-caps-lock-color = "009ddc";
    };
  };
}
