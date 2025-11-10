{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.wifi-hotspot-fallback;
  
  hotspotwifi = pkgs.writeShellScriptBin "hotspot-wifi" ''
    set -e
    
    INTERFACE="wlan0"
    HOTSPOT_SSID="${cfg.ssid}"
    HOTSPOT_IP="192.168.50.1"
    CHECK_INTERVAL=30
    FAILURE_THRESHOLD=3
    STATE_FILE="/var/lib/wifi-hotspot-fallback/state"
    MODE_FILE="/var/lib/wifi-hotspot-fallback/mode"
    
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
      if [ -f "$MODE_FILE" ]; then
        cat "$MODE_FILE"
      else
        echo "client"
      fi
    }
    
    set_mode() {
      echo "$1" > "$MODE_FILE"
    }
    
    get_failure_count() {
      if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
      else
        echo "0"
      fi
    }
    
    set_failure_count() {
      echo "$1" > "$STATE_FILE"
    }
    
    start_hotspot() {
      log "Starting WiFi hotspot mode..."
      
      ${pkgs.systemd}/bin/systemctl stop wpa_supplicant
      sleep 2
      
      ${pkgs.iproute2}/bin/ip addr flush dev $INTERFACE
      ${pkgs.iproute2}/bin/ip addr add $HOTSPOT_IP/24 dev $INTERFACE
      ${pkgs.iproute2}/bin/ip link set $INTERFACE up
      
      ${pkgs.systemd}/bin/systemctl start hostapd
      ${pkgs.systemd}/bin/systemctl start dnsmasq-hotspot
      
      set_mode "hotspot"
      log "WiFi hotspot started successfully (SSID: $HOTSPOT_SSID, IP: $HOTSPOT_IP)"
    }
    
    stop_hotspot() {
      log "Stopping WiFi hotspot mode..."
      
      ${pkgs.systemd}/bin/systemctl stop dnsmasq-hotspot
      ${pkgs.systemd}/bin/systemctl stop hostapd
      
      ${pkgs.iproute2}/bin/ip addr flush dev $INTERFACE
      
      ${pkgs.systemd}/bin/systemctl start wpa_supplicant
      
      set_mode "client"
      log "WiFi client mode restored"
    }
    
    mkdir -p /var/lib/wifi-hotspot-fallback
    
    while true; do
      current_mode=$(get_mode)
      
      if check_internet; then
        log "Internet connectivity: OK"
        set_failure_count 0
        
        if [ "$current_mode" = "hotspot" ]; then
          log "Internet restored, switching back to client mode..."
          stop_hotspot
        fi
      else
        failure_count=$(get_failure_count)
        failure_count=$((failure_count + 1))
        set_failure_count $failure_count
        
        log "Internet connectivity: FAILED (attempt $failure_count/$FAILURE_THRESHOLD)"
        
        if [ $failure_count -ge $FAILURE_THRESHOLD ] && [ "$current_mode" = "client" ]; then
          log "Failure threshold reached, switching to hotspot mode..."
          start_hotspot
        fi
      fi
      
      sleep $CHECK_INTERVAL
    done
  '';
in

{
  options.services.wifi-hotspot-fallback = {
    enable = mkEnableOption "automatic WiFi hotspot fallback";
    
    ssid = mkOption {
      type = types.str;
      default = "pilab-recovery";
      description = "SSID for the fallback hotspot";
    };
    
    passwordFile = mkOption {
      type = types.path;
      description = "Path to file containing the WPA passphrase";
    };
    
    interface = mkOption {
      type = types.str;
      default = "wlan0";
      description = "WiFi interface to use for hotspot";
    };
    
    channel = mkOption {
      type = types.int;
      default = 6;
      description = "WiFi channel for the hotspot";
    };
  };
  
  config = mkIf cfg.enable {
    
    environment.systemPackages = with pkgs; [
      hostapd
      dnsmasq
      iw
      hotspotwifi
    ];
    
    environment.etc."hostapd/hostapd.conf".text = ''
      interface=${cfg.interface}
      driver=nl80211
      ssid=${cfg.ssid}
      hw_mode=g
      channel=${toString cfg.channel}
      wmm_enabled=0
      macaddr_acl=0
      auth_algs=1
      ignore_broadcast_ssid=0
      wpa=2
      wpa_passphrase=@@PASSPHRASE@@
      wpa_key_mgmt=WPA-PSK
      wpa_pairwise=TKIP
      rsn_pairwise=CCMP
      country_code=IN
    '';
    
    environment.etc."dnsmasq-hotspot.conf".text = ''
      interface=${cfg.interface}
      bind-interfaces
      server=8.8.8.8
      domain-needed
      bogus-priv
      dhcp-range=192.168.50.10,192.168.50.100,12h
      dhcp-option=3,192.168.50.1
      dhcp-option=6,192.168.50.1
      address=/#/192.168.50.1
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
        sed "s|@@PASSPHRASE@@|$(cat ${cfg.passwordFile})|g" \
          /etc/hostapd/hostapd.conf > /run/hostapd.conf
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
      };
    };
    
    systemd.tmpfiles.rules = [
      "d /var/lib/wifi-hotspot-fallback 0755 root root -"
    ];
  };
}
