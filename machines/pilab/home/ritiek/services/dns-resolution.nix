{ config, pkgs, ... }:

let
  dns-update-pihole = (pkgs.writers.writePython3Bin "dns-update-pihole" {
    flakeIgnore = [ "E501" "W293" "E302" "F401" "E305" ];
  } ''
import urllib.request
import urllib.parse
import urllib.error
import http.cookiejar
import json
import re
import sys
import os
from typing import List, Tuple, Optional, Dict

# Load configuration from JSON file
CONFIG_FILE = "/media/HOMELAB_MEDIA/services/pihole/dns-resolution.json"

def load_sops_env():
    """Load environment variables from SOPS secrets file"""
    sops_env_path = os.path.expanduser("~/.config/sops-nix/secrets/dns-resolution.env")
    
    if os.path.exists(sops_env_path):
        print("Loading credentials from dns-resolution.env")
        try:
            with open(sops_env_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        os.environ[key] = value
            print("Successfully loaded credentials from dns-resolution.env")
        except Exception as e:
            print(f"Warning: Failed to load dns-resolution.env: {e}")
    else:
        print("Warning: dns-resolution.env not found, using existing environment variables")

def get_pihole_password():
    """Get Pi-hole password from environment variables"""
    password = os.environ.get('PIHOLE_APP_PASSWORD')
    if password:
        print("Using Pi-hole password from PIHOLE_APP_PASSWORD environment variable")
        return password
    else:
        print("Error: PIHOLE_APP_PASSWORD environment variable not set")
        return None

def load_config() -> Dict[str, str]:
    """Load MAC to hostname mapping from JSON file"""
    try:
        with open(CONFIG_FILE, "r") as f:
            mac_to_hostname = json.load(f)
        print(f"Loaded configuration from {CONFIG_FILE}")
        print(f"Found {len(mac_to_hostname)} MAC to hostname mappings")
        return mac_to_hostname
    except FileNotFoundError:
        print(f"Warning: Config file {CONFIG_FILE} not found, using empty mapping")
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing config file: {e}")
        print("Using empty mapping")
        return {}


class RouterARPFetcher:
    def __init__(self, router_host: str = None):
        self.router_host = router_host or os.environ.get('ROUTER_HOST')
        if not self.router_host:
            print("Error: ROUTER_HOST environment variable not set")
            return
        if ':' in self.router_host:
            host_part, port_part = self.router_host.rsplit(':', 1)
            self.router_ip = host_part
            self.router_port = port_part
        else:
            self.router_ip = self.router_host
            self.router_port = '80'
        self.router_base_url = f"http://{self.router_ip}:{self.router_port}"
        self.cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookie_jar)
        )

    def authenticate(self) -> bool:
        print("Authenticating with router...")
        
        username = os.environ.get('ROUTER_USERNAME')
        password_hash = os.environ.get('ROUTER_PASSWORD_HASH')
        
        if not username or not password_hash:
            print("Error: Router credentials not found")
            print("Set these environment variables:")
            print("  - ROUTER_USERNAME")
            print("  - ROUTER_PASSWORD_HASH")
            return False
        
        print(f"Using router username: {username}")
        
        login_url = f"{self.router_base_url}/boaform/admin/formLogin"
        login_data = urllib.parse.urlencode({
            "challenge": "",
            "username": username,
            "password": password_hash,
            "save": "Login",
            "submit-url": "/admin/login.asp",
            "postSecurityFlag": "63179"
        }).encode("utf-8")
        
        try:
            req = urllib.request.Request(login_url, data=login_data, method="POST")
            req.add_header("Content-Type", "application/x-www-form-urlencoded")
            response = self.opener.open(req, timeout=10)
            
            if response.getcode() == 200:
                print("Router login successful")
                
                arp_url = f"{self.router_base_url}/arptable.asp?v=1759053170000"
                req = urllib.request.Request(arp_url)
                response = self.opener.open(req, timeout=10)
                response_text = response.read().decode('utf-8')
                
                if "ARP Table" in response_text or "User List" in response_text:
                    print("Successfully authenticated and can access ARP table")
                    return True
                else:
                    print("Authentication succeeded but ARP table access failed")
                    return False
            else:
                print(f"Router login failed: HTTP {response.getcode()}")
                return False
        except Exception as e:
            print(f"Router authentication failed: {e}")
            return False

    def fetch_arp_table(self) -> Optional[str]:
        print("Fetching ARP table...")
        arp_url = f"{self.router_base_url}/arptable.asp?v=1759053170000"
        
        try:
            req = urllib.request.Request(arp_url)
            response = self.opener.open(req, timeout=10)
            if response.getcode() == 200:
                print("Successfully fetched ARP table")
                return response.read().decode("utf-8")
            else:
                print(f"Failed to fetch ARP table: HTTP {response.getcode()}")
                return None
        except urllib.error.URLError as e:
            print(f"Error fetching ARP table: {e}")
            return None

    def parse_arp_table(self, arp_html: str) -> List[Tuple[str, str]]:
        print("Parsing ARP table...")
        entries = []
        
        pattern = r'<td>([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s+</td><td>([a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2})\s+</td>'
        
        matches = re.findall(pattern, arp_html)
        
        for ip, mac in matches:
            mac_formatted = mac.upper().replace("-", ":")
            entries.append((ip, mac_formatted))
        
        return entries


class PiHoleDNSUpdater:
    def __init__(self, pihole_host: str = None):
        self.pihole_host = pihole_host or os.environ.get('PIHOLE_HOST')
        if not self.pihole_host:
            print("Error: PIHOLE_HOST environment variable not set")
            return
        if ':' in self.pihole_host:
            host_part, port_part = self.pihole_host.rsplit(':', 1)
            self.pihole_ip = host_part
            self.pihole_port = port_part
        else:
            self.pihole_ip = self.pihole_host
            self.pihole_port = '80'
        self.pihole_base_url = f"http://{self.pihole_ip}:{self.pihole_port}"
        self.sid = None

    def authenticate(self, password: str) -> bool:
        print("Authenticating with Pi-hole...")
        auth_url = f"{self.pihole_base_url}/api/auth"
        auth_data = {"password": password}
        
        try:
            data = json.dumps(auth_data).encode("utf-8")
            req = urllib.request.Request(auth_url, data=data, method="POST")
            req.add_header("Content-Type", "application/json")
            
            response = urllib.request.urlopen(req, timeout=10)
            if response.getcode() == 200:
                auth_response = json.loads(response.read().decode("utf-8"))
                if auth_response.get("session", {}).get("valid"):
                    self.sid = auth_response["session"]["sid"]
                    print(f"Successfully authenticated with Pi-hole. SID: {self.sid[:8]}...")
                    return True
                else:
                    print("Pi-hole authentication failed: Invalid session")
                    return False
            else:
                print(f"Failed to authenticate with Pi-hole: HTTP {response.getcode()}")
                return False
        except urllib.error.URLError as e:
            print(f"Error authenticating with Pi-hole: {e}")
            return False

    def get_current_dns_entries(self) -> List[str]:
        print("Fetching current DNS entries from Pi-hole...")
        config_url = f"{self.pihole_base_url}/api/config?sid={self.sid}"
        
        try:
            req = urllib.request.Request(config_url)
            response = urllib.request.urlopen(req, timeout=10)
            if response.getcode() == 200:
                config_data = json.loads(response.read().decode('utf-8'))
                hosts = config_data.get('config', {}).get('dns', {}).get('hosts', [])
                print(f"Found {len(hosts)} existing DNS entries")
                return hosts
            else:
                print(f"Failed to fetch DNS entries: HTTP {response.getcode()}")
                return []
        except urllib.error.URLError as e:
            print(f"Error fetching DNS entries: {e}")
            return []

    def update_dns_entries(self, dns_entries: List[str]) -> bool:
        print("Updating Pi-hole DNS entries...")
        update_url = f"{self.pihole_base_url}/api/config?sid={self.sid}"
        update_data = {
            "config": {
                "dns": {
                    "hosts": dns_entries
                }
            }
        }
        
        try:
            data = json.dumps(update_data).encode('utf-8')
            req = urllib.request.Request(update_url, data=data, method='PATCH')
            req.add_header('Content-Type', 'application/json')
            
            response = urllib.request.urlopen(req, timeout=30)
            if response.getcode() == 200:
                result = json.loads(response.read().decode('utf-8'))
                if 'config' in result and 'dns' in result['config']:
                    print("Successfully updated Pi-hole DNS entries")
                    return True
                else:
                    print("Failed to update DNS entries: Invalid response")
                    return False
            else:
                print(f"Failed to update DNS entries: HTTP {response.getcode()}")
                return False
        except urllib.error.URLError as e:
            print(f"Error updating DNS entries: {e}")
            return False

def main():
    print("Starting Pi-hole DNS update script...")
    
    load_sops_env()
    
    pihole_password = get_pihole_password()
    if not pihole_password:
        sys.exit(1)
    
    mac_to_hostname = load_config()
    
    router_fetcher = RouterARPFetcher()
    pihole_updater = PiHoleDNSUpdater()
    
    if not router_fetcher.authenticate():
        print("Failed to authenticate with router")
        sys.exit(1)
    
    arp_html = router_fetcher.fetch_arp_table()
    if not arp_html:
        print("Failed to fetch ARP table")
        sys.exit(1)
    
    arp_entries = router_fetcher.parse_arp_table(arp_html)
    if not arp_entries:
        print("No ARP entries found")
        sys.exit(1)
    
    print(f"Found {len(arp_entries)} ARP entries from router")
    
    print("\nDevice Information from Router:")
    print("=" * 55)
    print(f"{'#':<3} {'IP Address':<15} {'MAC Address':<18} {'Hostname'}")
    print("-" * 55)
    for i, (ip, mac) in enumerate(arp_entries, 1):
        fallback_hostname = f"unknown-{mac.replace(':', '-').lower()}.pihole"
        hostname = mac_to_hostname.get(mac, fallback_hostname)
        print(f"{i:<3} {ip:<15} {mac:<18} {hostname}")
    print("=" * 55)
    print()
    
    if not pihole_updater.authenticate(pihole_password):
        print("Failed to authenticate with Pi-hole")
        sys.exit(1)
    
    current_entries = pihole_updater.get_current_dns_entries()
    
    new_entries = current_entries.copy()
    existing_ips = {entry.split()[0]: entry for entry in current_entries if ' ' in entry}
    
    added_count = 0
    updated_count = 0
    
    print()

    for ip, mac in arp_entries:
        fallback_hostname = f"unknown-{mac.replace(':', '-').lower()}.pihole"
        hostname = mac_to_hostname.get(mac, fallback_hostname)
        new_entry = f"{ip} {hostname}"
        
        if ip in existing_ips:
            current_entry = existing_ips[ip]
            entry_parts = current_entry.split()
            current_hostname = entry_parts[1] if len(entry_parts) > 1 else ""
            if current_hostname != hostname:
                print(f"Updating entry for {ip}: {current_hostname} -> {hostname}")
                for i, entry in enumerate(new_entries):
                    if entry.split()[0] == ip:
                        new_entries[i] = new_entry
                        break
                updated_count += 1
        else:
            print(f"Adding new entry: {new_entry}")
            new_entries.append(new_entry)
            added_count += 1
    
    print()
    print("Summary:")
    print(f"- Updated entries: {updated_count}")
    print(f"- Added entries: {added_count}")
    print(f"- Total entries: {len(new_entries)}")
    
    if updated_count > 0 or added_count > 0:
        if pihole_updater.update_dns_entries(new_entries):
            print("Pi-hole DNS update completed successfully!")
        else:
            print("Failed to update Pi-hole DNS entries!")
            sys.exit(1)
    else:
        print("No changes needed. All entries are up to date.")

if __name__ == "__main__":
    main()
  '');

  ping-uptime-kuma = (pkgs.writeShellScriptBin "ping-uptime-kuma@dns-resolution" ''
    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    source ~/.config/sops-nix/secrets/uptime-kuma.env

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/aI5UREFqil?status=$STATUS&msg=$SERVICE_RESULT&ping="
    curl_exit_code=$?

    if [ $curl_exit_code -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma succeeded."
    else
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma failed."
      exit $curl_exit_code
    fi
  '');

  dns-fetch-pihole = (pkgs.writeShellScriptBin "dns-fetch-pihole" ''
    source ~/.config/sops-nix/secrets/dns-resolution.env

    if [ -z "$PIHOLE_HOST" ] || [ -z "$PIHOLE_APP_PASSWORD" ]; then
      echo "Error: PIHOLE_HOST or PIHOLE_APP_PASSWORD not set"
      exit 1
    fi

    PIHOLE_URL="http://$PIHOLE_HOST"

    echo "Authenticating with Pi-hole..."
    SID=$(${pkgs.curl}/bin/curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"password\":\"$PIHOLE_APP_PASSWORD\"}" \
      "$PIHOLE_URL/api/auth" | ${pkgs.jq}/bin/jq -r '.session.sid // empty')

    if [ -z "$SID" ]; then
      echo "Error: Failed to authenticate with Pi-hole"
      exit 1
    fi

    echo "Fetching DNS records from Pi-hole..."
    echo "IP Address       Hostname"
    echo "=================================="
    ${pkgs.curl}/bin/curl -s "$PIHOLE_URL/api/config?sid=$SID" | \
      ${pkgs.jq}/bin/jq -r '.config.dns.hosts[]? // empty' | \
      while read -r entry; do
        if [ -n "$entry" ]; then
          ip=$(echo "$entry" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          hostname=$(echo "$entry" | ${pkgs.coreutils}/bin/cut -d' ' -f2-)
          printf "%-15s  %s\n" "$ip" "$hostname"
        fi
      done
  '');

  dns-fetch-router = (pkgs.writeShellScriptBin "dns-fetch-router" ''
    source ~/.config/sops-nix/secrets/dns-resolution.env

    if [ -z "$ROUTER_HOST" ] || [ -z "$ROUTER_USERNAME" ] || [ -z "$ROUTER_PASSWORD_HASH" ]; then
      echo "Error: ROUTER_HOST, ROUTER_USERNAME, or ROUTER_PASSWORD_HASH not set"
      exit 1
    fi

    ROUTER_URL="http://$ROUTER_HOST"
    COOKIE_JAR=$(${pkgs.coreutils}/bin/mktemp)

    echo "Authenticating with router..."
    ${pkgs.curl}/bin/curl -s -c "$COOKIE_JAR" -X POST \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "challenge=&username=$ROUTER_USERNAME&password=$ROUTER_PASSWORD_HASH&save=Login&submit-url=/admin/login.asp&postSecurityFlag=63179" \
      "$ROUTER_URL/boaform/admin/formLogin" > /dev/null

    if [ $? -ne 0 ]; then
      echo "Error: Failed to authenticate with router"
      ${pkgs.coreutils}/bin/rm -f "$COOKIE_JAR"
      exit 1
    fi

    echo "Fetching ARP table from router..."
    ARP_DATA=$(${pkgs.curl}/bin/curl -s -b "$COOKIE_JAR" "$ROUTER_URL/arptable.asp?v=1759053170000")

    if [ $? -ne 0 ]; then
      echo "Error: Failed to fetch ARP table"
      ${pkgs.coreutils}/bin/rm -f "$COOKIE_JAR"
      exit 1
    fi

    echo "IP Address       MAC Address        Status"
    echo "============================================"
    echo "$ARP_DATA" | ${pkgs.gnugrep}/bin/grep -oP '<td>[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+</td><td>[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}\s+</td>' | \
      ${pkgs.gnused}/bin/sed 's/<td>\([0-9\.]*\)\s*<\/td><td>\([a-fA-F0-9:-]*\)\s*<\/td>/\1 \2/' | \
      while read -r ip mac; do
        if [ -n "$ip" ] && [ -n "$mac" ]; then
          mac_formatted=$(echo "$mac" | ${pkgs.coreutils}/bin/tr 'a-f-' 'A-F:')
          printf "%-15s  %-17s  Active\n" "$ip" "$mac_formatted"
        fi
      done

    ${pkgs.coreutils}/bin/rm -f "$COOKIE_JAR"
  '');
in
{
  sops.secrets."dns-resolution.env" = {};
  sops.secrets."uptime-kuma.env" = {};

  home.packages = with pkgs; [
    dns-update-pihole
    dns-fetch-pihole
    dns-fetch-router
    curl
    jq
  ];

  systemd.user.services.dns-resolution = {
    Unit = {
      Description = "Update Pi-hole DNS entries with current network devices from router ARP table";
      After = [ "network-online.target" "docker-pihole.service" ];
      Wants = [ "network-online.target" ];
      Requires = [ "docker-pihole.service" ];
      RequiresMountsFor = [ "/media/HOMELAB_MEDIA/services/pihole" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${dns-update-pihole}/bin/dns-update-pihole";
      ExecStopPost = "${ping-uptime-kuma}/bin/ping-uptime-kuma@dns-resolution";
    };
  };

  systemd.user.timers.dns-resolution = {
    Unit = {
      Description = "Periodically update Pi-hole DNS entries with current network devices";
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
      Unit = "dns-resolution.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
