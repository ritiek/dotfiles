{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: with ps; [ spidev libgpiod pillow ]);
in
{
  # Waveshare 2.13" Touch e-Paper HAT (SPI3 + GPIO, see hw-config.nix).
  systemd.services.epaper = {
    description = "E-paper page: voltage graph and weekly sleep from Home Assistant";
    wantedBy = [ "multi-user.target" ];
    after = [ "home-assistant.service" ];
    serviceConfig = {
      # Root: spidev/gpiochip nodes and the recorder DB are root/hass-only.
      ExecStart = "${python}/bin/python3 -u ${./epd_ha.py}";
      Restart = "always";
      RestartSec = "30s";
    };
  };
}
