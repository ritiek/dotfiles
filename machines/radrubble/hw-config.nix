{ config, lib, pkgs, modulesPath, inputs, ... }:

let
  noZFS = {
    inputs.nixpkgs.overlays = [
      (final: super: {
        zfs = super.zfs.overrideAttrs (_: { meta.platforms = [ ]; });
      })
    ];
  };
in
{
  imports = [
    inputs.rockchip.nixosModules.sdImageRockchip
    inputs.rockchip.nixosModules.noZFS
    ./aic8800.nix
  ];

  # pkgs.armbian-firmware is non-free.
  # nixpkgs.config.allowUnfree = true;
  # hardware.firmware = with pkgs; [ armbian-firmware linux-firmware ];

  rockchip.uBoot = pkgs.ubootRadxaZero3W;
  # boot.kernelPackages = inputs.rockchip.legacyPackages."aarch64-linux".kernel_linux_latest_rockchip_unstable;

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # The aic8800 driver registers its own permissive custom regulatory rules
  # ("USING PERMISSIVE CUSTOM REGULATORY RULES" in dmesg) and ignores the kernel
  # regdom, so 5GHz is never gated by cfg80211 regdom. Shipping the regulatory DB
  # is harmless and cheap; the kernel regdom hint does nothing here but is kept
  # for documentation. (regdom is NOT the cause of the cold-boot WiFi flakiness.)
  hardware.wirelessRegulatoryDatabase = true;
  boot.kernelParams = [ "cfg80211.ieee80211_regdom=IN" ];

  # Cold-boot WiFi race: the aic8800 SDIO firmware is still settling when
  # wpa_supplicant begins associating. Early attempts fail locally with
  # "CTRL-EVENT-ASSOC-REJECT bssid=00:00:00:00:00:00 status_code=1" on BOTH
  # bands, and wpa_supplicant then gets stuck in a TEMP-DISABLED retry loop while
  # the unit stays active(running) — so systemd Restart= never fires and wlan0
  # is left with only a 169.254.x link-local address. A simple
  # `systemctl restart wpa_supplicant` once the firmware has settled recovers
  # immediately. This watchdog does exactly that: after a grace period it checks
  # for a real (non-link-local) IPv4 on wlan0 and restarts wpa_supplicant until
  # one appears.
  systemd.services.wifi-watchdog = {
    description = "Restart wpa_supplicant until wlan0 gets a real IP (aic8800 cold-boot race)";
    after = [ "wpa_supplicant.service" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 pkgs.systemd pkgs.gnugrep pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      # Give a healthy boot time to associate + DHCP without any interference.
      sleep 30
      for i in $(seq 1 6); do
        ip=$(ip -4 -o addr show wlan0 2>/dev/null | grep -v '169\.254\.' | grep -oP 'inet \K[0-9.]+' | head -1)
        if [ -n "$ip" ]; then
          echo "wlan0 has real IP $ip (attempt $i) - WiFi up"
          exit 0
        fi
        echo "wlan0 has no real IP (attempt $i) - restarting wpa_supplicant"
        systemctl restart wpa_supplicant.service || true
        sleep 20
      done
      echo "wifi-watchdog: gave up after retries (wlan0 still has no real IP)"
      exit 0
    '';
  };
}
