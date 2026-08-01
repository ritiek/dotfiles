{ config, lib, pkgs, ... }:
{
  # NetworkManager-based wifi, reusing the same "wpa_supplicant" secret
  # (network={ ssid="..." psk="..." priority=N } blocks) as modules/wifi/wpa_supplicant.nix
  # so adding/removing networks only ever requires editing secrets.yaml.
  hardware.wirelessRegulatoryDatabase = true;
  boot.kernelParams = [ "cfg80211.ieee80211_regdom=IN" ];

  networking.networkmanager.enable = true;
  # Default path, no chroot bind-mount needed. nm-wifi-profiles is a oneshot
  # that reads this file once and pushes the networks into NetworkManager, so
  # edits to the secret only land after it runs again.
  sops.secrets.wpa_supplicant = {
    restartUnits = [ "nm-wifi-profiles.service" ];
  };

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
