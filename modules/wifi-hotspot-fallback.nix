{ config, pkgs, lib, ... }:

let
  cfg = config.services.wifi-hotspot-fallback;

  hotspotwifi = pkgs.writeShellScriptBin "hotspot-wifi" ''
    # WiFi hotspot fallback script - v2
    set -e

    INTERFACE="${cfg.interface}"
    ${lib.optionalString (cfg.ssidFile != null) ''
    HOTSPOT_SSID="$(cat ${cfg.ssidFile})"
    ''}
    ${lib.optionalString (cfg.ssidFile == null) ''
    HOTSPOT_SSID="${cfg.ssid}"
    ''}
    HOTSPOT_IP="192.168.50.1"
    CHECK_INTERVAL=30
    FAILURE_THRESHOLD=3
    STATE_FILE="/var/lib/wifi-hotspot-fallback/state"
    MODE_FILE="/var/lib/wifi-hotspot-fallback/mode"
    SCAN_INTERVAL=300  # Scan for known networks every 5 minutes in hotspot mode

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | ${pkgs.systemd}/bin/systemd-cat -t hotspot-wifi -p info
    }

    check_internet() {
      if ${pkgs.iputils}/bin/ping -c 1 -W 2 8.8.8.8 &> /dev/null || \
         ${pkgs.iputils}/bin/ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
        return 0
      else
        return 1
      fi
    }

    get_mode() {
      if [ -f "''${MODE_FILE}" ]; then
        cat "''${MODE_FILE}"
      else
        echo "client"
      fi
    }

    set_mode() {
      echo "$1" > "''${MODE_FILE}"
    }

    get_failure_count() {
      if [ -f "''${STATE_FILE}" ]; then
        cat "''${STATE_FILE}"
      else
        echo "0"
      fi
    }

    set_failure_count() {
      echo "$1" > "''${STATE_FILE}"
    }

    get_last_scan_time() {
      local scan_file="/var/lib/wifi-hotspot-fallback/last_scan"
      if [ -f "''${scan_file}" ]; then
        cat "''${scan_file}"
      else
        echo "0"
      fi
    }

    set_last_scan_time() {
      echo "$1" > "/var/lib/wifi-hotspot-fallback/last_scan"
    }

    scan_for_known_networks() {
      log "Scanning for known WiFi networks..."
      local current_time=$(date +%s)
      local last_scan=$(get_last_scan_time)
      local interface="''${INTERFACE}"

      # Only scan if SCAN_INTERVAL has passed
      if [ $((current_time - last_scan)) -lt ''${SCAN_INTERVAL} ]; then
        return 1
      fi

      set_last_scan_time "''${current_time}"

      # Scan for networks and check if any known networks are available
      local scan_result=$(${pkgs.iw}/bin/iw dev ''${interface} scan 2>/dev/null | grep "SSID:" | cut -d: -f2 | sed 's/^ *//;s/ *$//')

      # Get known networks from wpa_supplicant configuration
      local known_networks=""
      if [ -f "/etc/wpa_supplicant.conf" ]; then
        known_networks=$(grep '^ssid=' /etc/wpa_supplicant.conf | cut -d= -f2 | sed 's/"//g')
      fi

      # Check if any known networks are in scan results
      for known_ssid in ''${known_networks}; do
        if echo "$scan_result" | grep -q "^''${known_ssid}$"; then
          log "Known network found: ''${known_ssid}"
          return 0
        fi
      done

      log "No known networks found in scan"
      return 1
    }

    create_virtual_interface() {
      # Create virtual interface for concurrent client+hotspot mode
      local interface="''${INTERFACE}"
      local phy_name=$(${pkgs.iw}/bin/iw dev ''${interface} info | grep wiphy | cut -d' ' -f2)
      if ! ${pkgs.iw}/bin/iw phy phy''${phy_name} interface add ''${interface}_ap type __ap; then
        log "Failed to create virtual interface ''${interface}_ap, using single interface mode"
        return 1
      fi
      return 0
    }

    remove_virtual_interface() {
      local interface="''${INTERFACE}"
      ${pkgs.iw}/bin/iw dev ''${interface}_ap del 2>/dev/null || true
    }

    start_hotspot() {
      log "Starting WiFi hotspot mode..."
      local interface="''${INTERFACE}"
      local hotspot_interface

      # Try to create virtual interface for concurrent mode
      if create_virtual_interface; then
        hotspot_interface="''${interface}_ap"
        log "Using virtual interface ''${hotspot_interface} for hotspot"
      else
        hotspot_interface="''${interface}"
        log "Stopping wpa_supplicant for single interface hotspot mode"
        ${pkgs.systemd}/bin/systemctl stop wpa_supplicant.service
        sleep 2
      fi

      # Configure hotspot interface
      ${pkgs.iproute2}/bin/ip addr flush dev ''${hotspot_interface}
      ${pkgs.iproute2}/bin/ip addr add ''${HOTSPOT_IP}/24 dev ''${hotspot_interface}
      ${pkgs.iproute2}/bin/ip link set ''${hotspot_interface} up

      # Start hotspot services
      ${pkgs.systemd}/bin/systemctl start hostapd
      ${pkgs.systemd}/bin/systemctl start dnsmasq-hotspot

      set_mode "hotspot"
      log "WiFi hotspot started successfully (SSID: ''${HOTSPOT_SSID}, IP: ''${HOTSPOT_IP}, Interface: ''${hotspot_interface})"
    }

    stop_hotspot() {
      log "Stopping WiFi hotspot mode..."
      local interface="''${INTERFACE}"
      local hotspot_interface="''${interface}_ap"

      # Stop hotspot services
      ${pkgs.systemd}/bin/systemctl stop dnsmasq-hotspot
      ${pkgs.systemd}/bin/systemctl stop hostapd

      current_mode=$(get_mode)

      # Check if we're using virtual interface
      if ${pkgs.iw}/bin/iw dev ''${hotspot_interface} info &>/dev/null; then
        log "Removing virtual interface ''${hotspot_interface}"
        ${pkgs.iproute2}/bin/ip addr flush dev ''${hotspot_interface}
        remove_virtual_interface
      else
        log "Restoring wpa_supplicant for single interface mode"
        ${pkgs.iproute2}/bin/ip addr flush dev ''${interface}
        ${pkgs.systemd}/bin/systemctl start wpa_supplicant.service
      fi

      set_mode "client"
      log "WiFi client mode restored"
    }

    # Create state directory
    mkdir -p /var/lib/wifi-hotspot-fallback

    # Main monitoring loop
    while true; do
      current_mode=$(get_mode)

      if check_internet; then
        log "Internet connectivity: OK"
        set_failure_count "0"

        if [ "''${current_mode}" = "hotspot" ]; then
          log "Internet restored, switching back to client mode..."
          stop_hotspot
        fi
      else
        failure_count=$(get_failure_count)
        failure_count=$((failure_count + 1))
        set_failure_count ''${failure_count}

        log "Internet connectivity: FAILED (attempt ''${failure_count}/''${FAILURE_THRESHOLD})"

        if [ ''${failure_count} -ge ''${FAILURE_THRESHOLD} ]; then
          if [ "''${current_mode}" != "hotspot" ]; then
            log "Failure threshold reached, switching to hotspot mode..."
            start_hotspot
          else
            # Already in hotspot mode, check for known networks periodically
            if scan_for_known_networks; then
              log "Known network detected, attempting to reconnect..."
              stop_hotspot
              set_failure_count "0"  # Reset failure count to give reconnection a chance
            fi
          fi
        fi
      fi

      sleep ''${CHECK_INTERVAL}
    done
  '';

in

{
  options.services.wifi-hotspot-fallback = {
    enable = lib.mkEnableOption "automatic WiFi hotspot fallback";

    ssid = lib.mkOption {
      type = lib.types.str;
      default = "pilab-recovery";
      description = "SSID for fallback hotspot";
    };

    ssidFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing SSID for fallback hotspot";
    };

    passwordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing WPA passphrase";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "WiFi interface to use for hotspot";
    };

    channel = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "WiFi channel for hotspot";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      hostapd
      dnsmasq
      iw
      hotspotwifi
    ];

    environment.etc."hostapd/hostapd.conf".text = ''
      interface=${cfg.interface}
      driver=nl80211
      ssid=${if cfg.ssidFile != null then "@@SSID@@" else cfg.ssid}
      hw_mode=g
      channel=${builtins.toString cfg.channel}
      wmm_enabled=0
      macaddr_acl=0
      auth_algs=1
      ignore_broadcast_ssid=0
      wpa=2
      wpa_passphrase=@@PASSPHRASE@@
      wpa_key_mgmt=WPA-PSK
      rsn_pairwise=CCMP
      country_code=IN
    '';

    environment.etc."dnsmasq-hotspot.conf".text = ''
      interface=${cfg.interface}
      bind-interfaces
      port=0
      dhcp-range=192.168.50.10,192.168.50.100,12h
      dhcp-option=3,192.168.50.1
      dhcp-option=6,127.0.0.1
      dhcp-leasefile=/var/lib/wifi-hotspot-fallback/dnsmasq.leases
    '';

    systemd.services.hostapd = {
      description = "WiFi Hotspot Access Point";
      after = [ "network.target" ];
      wantedBy = [ ];

      serviceConfig = {
        Type = "forking";
        PIDFile = "/run/hostapd.pid";
        Restart = "no";
        RestartSec = 5;
      };

      preStart = ''
        # Use virtual interface if available, otherwise main interface
        INTERFACE="${cfg.interface}"
        if ${pkgs.iw}/bin/iw dev ''${INTERFACE}_ap info &>/dev/null; then
          INTERFACE="''${INTERFACE}_ap"
        fi

        ${if cfg.ssidFile != null then ''
        sed -e "s|@@PASSPHRASE@@|$(cat ${cfg.passwordFile})|g" \
            -e "s|@@SSID@@|$(cat ${cfg.ssidFile})|g" \
            /etc/hostapd/hostapd.conf > /run/hostapd.conf
        '' else ''
        sed "s|@@PASSPHRASE@@|$(cat ${cfg.passwordFile})|g" \
            /etc/hostapd/hostapd.conf > /run/hostapd.conf
        ''}
        sed -i "s|interface=${cfg.interface}|interface=''${INTERFACE}|g" /run/hostapd.conf
      '';

      script = ''
        ${pkgs.hostapd}/bin/hostapd -B -P /run/hostapd.pid /run/hostapd.conf
      '';

      postStop = ''
        rm -f /run/hostapd.conf /run/hostapd.pid
      '';
    };

    systemd.services.dnsmasq-hotspot = {
      description = "DHCP and DNS server for WiFi hotspot";
      after = [ "network.target" "hostapd.service" ];
      wantedBy = [ ];

      serviceConfig = {
        Type = "forking";
        PIDFile = "/run/dnsmasq-hotspot.pid";
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --conf-file=/etc/dnsmasq-hotspot.conf --pid-file=/run/dnsmasq-hotspot.pid";
        Restart = "no";
        RestartSec = 5;
      };

      preStart = ''
        # Use virtual interface if available, otherwise main interface
        INTERFACE="${cfg.interface}"
        if ${pkgs.iw}/bin/iw dev ''${INTERFACE}_ap info &>/dev/null; then
          INTERFACE="''${INTERFACE}_ap"
        fi

        sed "s|interface=${cfg.interface}|interface=''${INTERFACE}|g" \
          /etc/dnsmasq-hotspot.conf > /run/dnsmasq-hotspot.conf
      '';

      postStop = ''
        rm -f /run/dnsmasq-hotspot.conf /run/dnsmasq-hotspot.pid
      '';
    };

    systemd.services.wifi-hotspot-monitor = {
      description = "Monitor internet connectivity and manage WiFi hotspot fallback";
      after = [ "network-online.target" "wpa_supplicant.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${hotspotwifi}/bin/hotspot-wifi";
        Restart = "always";
        RestartSec = 10;
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/wifi-hotspot-fallback 0755 root root -"
    ];
  };
}
