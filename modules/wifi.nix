{ config, ... }:
{
  # Ref: https://github.com/NixOS/nixpkgs/pull/180872
  sops.secrets."wpa_supplicant".path = "/etc/wpa_supplicant/imperative.conf";
  networking.wireless = {
    enable = true;
    allowAuxiliaryImperativeNetworks = true;
    networks = {
      "SSID".psk = "PASS_PLAIN";
    };
    interfaces = [ ];
    extraConfig = ''
      country=IN
      p2p_disabled=1
    '';
  };

  # wpa_supplicant runs in a chroot (RootDirectory=/run/wpa_supplicant).
  # The sops secret symlink /etc/wpa_supplicant/imperative.conf -> /run/secrets/wpa_supplicant
  # can't be resolved inside the chroot unless we explicitly bind-mount it.
  # It must be read-WRITE (not read-only) because the unit's ExecStartPre runs
  # `touch`/`chmod`/`chown` on imperative.conf, which follows the symlink to this
  # target. A read-only bind mount makes those fail with "Read-only file system".
  systemd.services.wpa_supplicant.serviceConfig.BindPaths = [
    "/run/secrets/wpa_supplicant"
  ];
}
