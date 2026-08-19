{ config, ... }:
{
  # Bare passphrase, no trailing newline required: the hostapd module splices
  # it in with `wpa_passphrase=$(cat <file>)`, which strips trailing newlines
  # anyway. hostapd runs as root, so sops' default 0400 root mode is fine.
  sops.secrets."hostapd.psk".restartUnits = [ "hostapd.service" ];

  # Carried over from modules/wifi/network_manager.nix, which switchboard no
  # longer imports (a client-mode supplicant and hostapd cannot share this
  # radio). Without the regulatory database the kernel sits at country 00 and
  # marks channels 12/13 NO-IR.
  hardware.wirelessRegulatoryDatabase = true;
  boot.kernelParams = [ "cfg80211.ieee80211_regdom=IN" ];

  services.hostapd = {
    enable = true;

    radios.wlan0 = {
      band = "2g";

      # Hard-pinned. channel = 0 means ACS, which needs the driver to answer
      # NL80211_CMD_GET_SURVEY; fullMAC vendor drivers like aic8800_fdrv
      # generally do not, and hostapd then exits with
      # "ACS: Unable to collect survey data".
      channel = 6;

      # countryCode is deliberately NOT set.
      #
      # Setting it makes the module emit both country_code and ieee80211d=1,
      # which sends an NL80211_CMD_REQ_SET_REG hint. On the AIC8800 that
      # stalls hostapd in COUNTRY_UPDATE for 90+ seconds and it never reaches
      # AP-ENABLED, unless the requested domain already matches the active
      # one (radxa-pkg/aic8800#98). Because the domain persists across the
      # attempt, it appears to "work on the second boot" -- which looks like
      # an intermittent bug and is miserable to diagnose.
      #
      # cfg80211.ieee80211_regdom=IN above sets the domain at cfg80211 init,
      # so the kernel still enforces the IN limits (2402-2482 @ 40, 30 dBm,
      # channels 1-13, no NO-IR). The only thing given up is the 802.11d
      # country IE in beacons.

      # Worth roughly 4x on this chip: 49.7/29.7 Mbit/s with HT versus
      # 12.2/17.3 without. hostapd reports AP-ENABLED either way, so this
      # cannot be inferred from status output.
      wifi4 = {
        enable = true;
        # The module's default list renders as "[HT40]", but hostapd's parser
        # wants "[HT40+]" or "[HT40-]". Stick to HT20 with short GI: valid,
        # and 40 MHz on 2.4 GHz is antisocial anyway.
        capabilities = [ "SHORT-GI-20" ];
      };
      # Meaningless on 2.4 GHz, and HE on this driver is untested.
      wifi5.enable = false;
      wifi6.enable = false;

      networks.wlan0 = {
        ssid = "switchboard";

        # This driver reports "#{ AP } <= 1" in its interface combinations:
        # exactly one AP interface, no multi-BSS. A second SSID is not
        # possible, which is why IoT and trusted share one network for now.

        settings = {
          # There is no `bridge` option on this module, and it will not create
          # the bridge -- br-lan comes from modules/router/lan.nix. hostapd
          # does the enslavement itself so that networkd is not also trying to
          # own the interface while hostapd flips it into AP mode.
          bridge = "br-lan";

          # The module defaults this to 1 (MFP capable) for wpa2-sha1.
          # Forced off: ESP8266 has no SAE and no 802.11w support whatsoever,
          # and the advertised MFPC bit alone is enough to trip old client
          # parsers. pihole.nix's host list shows ESP8266/ESP32 sensors and
          # imou-* cameras on this network.
          ieee80211w = 0;
        };

        authentication = {
          # Not wpa3-sae or wpa3-sae-transition, for the same reason as
          # above. Once the ESP fleet is off this SSID, revisit.
          mode = "wpa2-sha1";

          # Not authentication.wpaPassword: that renders the passphrase into
          # the world-readable Nix store. The File variant is spliced in at
          # service start by the module's dynamicConfigScripts instead.
          wpaPasswordFile = config.sops.secrets."hostapd.psk".path;

          # Do not add GCMP here (enableRecommendedPairwiseCiphers): it is
          # untested on this chip and fails silently with
          # "Failed to set beacon parameters".
          pairwiseCiphers = [ "CCMP" ];
        };

        logLevel = 2;
      };
    };
  };

  # br-lan has to exist before hostapd tries to enslave wlan0 into it.
  systemd.services.hostapd = {
    after = [ "systemd-networkd.service" ];
    wants = [ "systemd-networkd.service" ];
  };
}
