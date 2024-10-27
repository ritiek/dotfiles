{ config, ... }:
{
  # Ref: https://github.com/NixOS/nixpkgs/pull/180872
  sops.secrets."wpa_supplicant".path = "/etc/wpa_supplicant.conf";
  networking.wireless = {
    enable = true;
    allowAuxiliaryImperativeNetworks = true;
    networks = {
      "SSID".psk = "PASS_PLAIN";
    };
    interfaces = [ "wlan0" ];
  };
}
