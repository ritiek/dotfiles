{ config, lib, pkgs, ... }:
{
  # NetworkManager-based wifi, reusing the same "wpa_supplicant" secret
  # (network={ ssid="..." psk="..." priority=N } blocks) as modules/wifi/wpa_supplicant.nix
  # so adding/removing networks only ever requires editing secrets.yaml.
  hardware.wirelessRegulatoryDatabase = true;
  boot.kernelParams = [ "cfg80211.ieee80211_regdom=IN" ];

  networking.networkmanager.enable = true;
  sops.secrets.wpa_supplicant = { }; # default path, no chroot bind-mount needed

  systemd.services.nm-wifi-profiles = {
    description = "Sync NetworkManager wifi profiles from secret";
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.networkmanager pkgs.gnugrep ];
    serviceConfig.Type = "oneshot";
    script = ''
      flat=$(tr '\n' ' ' < ${config.sops.secrets.wpa_supplicant.path})
      grep -oP 'network=\{[^}]*\}' <<< "$flat" | while read -r block; do
        ssid=$(grep -oP 'ssid="\K[^"]+' <<< "$block")
        psk=$(grep -oP 'psk="\K[^"]+' <<< "$block")
        priority=$(grep -oP 'priority=\K[0-9]+' <<< "$block")
        [ -z "$ssid" ] && continue
        if nmcli -t -f NAME connection show | grep -qFx "$ssid"; then
          nmcli connection modify "$ssid" wifi-sec.psk "$psk" connection.autoconnect-priority "$priority"
        else
          nmcli connection add type wifi con-name "$ssid" ifname "*" ssid "$ssid" \
            wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk" connection.autoconnect-priority "$priority"
        fi
      done
    '';
  };
}
