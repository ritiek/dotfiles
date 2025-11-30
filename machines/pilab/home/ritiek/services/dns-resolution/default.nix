{ config, pkgs, lib, ... }:

let
  # Router configuration - enable/disable routers and set priorities
  routerConfig = {
    arpscrape = {
      enabled = false;
      priority = 2;
    };
    tplink = {
      enabled = true;
      priority = 2;
    };
    airtel = {
      enabled = true;
      priority = 1;     # Lower priority = higher precedence for deduplication
    };
  };

  # Playwright browsers path (only when TP-Link router is enabled)
  playwrightBrowsers = lib.optionals (routerConfig.tplink.enabled || routerConfig.airtel.enabled) [
    pkgs.playwright-driver.browsers
  ];

  # Conditional Python environment based on enabled routers
  pythonEnv = pkgs.python3.withPackages (ps: [
    # Standard packages always included
  ] ++ lib.optionals routerConfig.tplink.enabled [
    # Include Playwright only when TP-Link router is enabled
    ps.playwright
  ]);

  # Router configuration as JSON
  routerConfigJson = builtins.toJSON routerConfig;

  # Main DNS resolution Python script with router manager
  dns-update-pihole-unwrapped = pkgs.writeScriptBin "dns-update-pihole-unwrapped" ''
    #!${pythonEnv}/bin/python3
    import urllib.request
    import urllib.parse
    import urllib.error
    import json
    import sys
    import os
    from typing import List, Dict, Optional

    # Add routers directory to Python path
    sys.path.insert(0, '${./routers}')

    # Import router modules
    from base import BaseRouter
    from arpscrape import ARPRouter
    from tplink import TPLinkRouter
    from airtel import AirtelRouter

    # Load configuration from JSON file
    CONFIG_FILE = "/media/HOMELAB_MEDIA/services/pihole/dns-resolution.json"

    def load_sops_env():
        """Load environment variables from SOPS secrets file"""
        sops_env_path = "${config.home.homeDirectory}/.config/sops-nix/secrets/dns-resolution.env"

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


    class RouterManager:
        """Manages multiple router scrapers and aggregates client data"""

        def __init__(self):
            self.routers = []
            self.config = json.loads('${routerConfigJson}')
            self._initialize_routers()

        def _initialize_routers(self):
            """Initialize enabled routers based on configuration"""
            router_classes = {
                "arpscrape": ARPRouter,
                "tplink": TPLinkRouter,
                "airtel": AirtelRouter
            }

            for router_name, router_config in self.config.items():
                if router_config.get("enabled", False):
                    try:
                        router_class = router_classes.get(router_name)
                        if router_class:
                            router = router_class()
                            self.routers.append({
                                "router": router,
                                "priority": router_config.get("priority", 999)
                            })
                            print(f"Initialized router: {router.name} (priority: {router_config.get('priority', 999)})")
                    except Exception as e:
                        print(f"Failed to initialize {router_name}: {e}")
                        import traceback
                        traceback.print_exc()

        def get_all_clients(self) -> List[Dict[str, str]]:
            """Get clients from all available routers"""
            all_clients = []

            for router_info in self.routers:
                router = router_info["router"]
                try:
                    if router.is_available():
                        clients = router.get_clients()
                        for client in clients:
                            client["source"] = router.name
                            client["priority"] = router_info["priority"]
                        all_clients.extend(clients)
                        print(f"Got {len(clients)} clients from {router.name}")
                    else:
                        print(f"Router {router.name} unavailable")
                except Exception as e:
                    print(f"Router {router.name} failed: {e}")
                    import traceback
                    traceback.print_exc()

            # Deduplicate by MAC address
            return self._deduplicate_clients(all_clients)

        def _deduplicate_clients(self, clients: List[Dict[str, str]]) -> List[Dict[str, str]]:
            """Deduplicate clients by MAC, preferring richer data and higher priority routers"""
            seen_macs = {}
            deduplicated = []

            # Sort by priority (lower number = higher priority)
            clients.sort(key=lambda c: c.get("priority", 999))

            for client in clients:
                mac = client["mac"].upper()
                if mac not in seen_macs:
                    seen_macs[mac] = client
                    deduplicated.append(client)
                else:
                    existing = seen_macs[mac]
                    # Prefer client with actual name over None or "unknown-*"
                    existing_name = existing.get("name")
                    client_name = client.get("name")

                    should_replace = False

                    # Priority 1: Client with real name beats client with no name
                    if client_name and not existing_name:
                        should_replace = True
                    elif client_name and existing_name and existing_name.startswith("unknown-") and not client_name.startswith("unknown-"):
                        should_replace = True
                    # Priority 2: Higher priority router (lower number)
                    elif client.get("priority", 999) < existing.get("priority", 999):
                        # Only replace if names are equivalent
                        if (not client_name and not existing_name) or \
                           (client_name == existing_name) or \
                           (client_name and client_name.startswith("unknown-") and existing_name and existing_name.startswith("unknown-")):
                            should_replace = True

                    if should_replace:
                        seen_macs[mac] = client
                        # Replace in deduplicated list
                        for i, c in enumerate(deduplicated):
                            if c["mac"].upper() == mac:
                                deduplicated[i] = client
                                break

            return deduplicated


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
        print("=" * 70)

        load_sops_env()

        pihole_password = get_pihole_password()
        if not pihole_password:
            sys.exit(1)

        mac_to_hostname = load_config()

        # Use router manager to get clients from all routers
        router_manager = RouterManager()
        pihole_updater = PiHoleDNSUpdater()

        # Get clients from all routers
        all_clients = router_manager.get_all_clients()
        if not all_clients:
            print("No clients found from any router")
            sys.exit(1)

        print(f"\nFound {len(all_clients)} total clients from all routers")

        # Print device information with source info
        print("\nDevice Information from All Routers:")
        print("=" * 80)
        print(f"{'#':<3} {'IP Address':<15} {'MAC Address':<18} {'Hostname':<25} {'Source'}")
        print("-" * 80)
        for i, client in enumerate(all_clients, 1):
            ip = client["ip"]
            mac = client["mac"]
            source = client["source"]
            hostname = mac_to_hostname.get(mac.upper(), "")
            print(f"{i:<3} {ip:<15} {mac:<18} {hostname:<25} {source}")
        print("=" * 80)
        print()

        # Authenticate with Pi-hole
        if not pihole_updater.authenticate(pihole_password):
            print("Failed to authenticate with Pi-hole")
            sys.exit(1)

        # Get current DNS entries
        current_entries = pihole_updater.get_current_dns_entries()

        # Build new entries
        new_entries = current_entries.copy()
        existing_ips = {entry.split()[0]: entry for entry in current_entries if ' ' in entry}

        added_count = 0
        updated_count = 0

        print()

        for client in all_clients:
            ip = client["ip"]
            mac = client["mac"]
            hostname = mac_to_hostname.get(mac.upper())

            if not hostname:
                continue

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
  '';

  # Wrapper script that sets Playwright environment variables
  dns-update-pihole = pkgs.writeShellScriptBin "dns-update-pihole" (
    if routerConfig.tplink.enabled then ''
      export PLAYWRIGHT_BROWSERS_PATH="${lib.concatStringsSep ":" playwrightBrowsers}"
      export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
      exec ${dns-update-pihole-unwrapped}/bin/dns-update-pihole-unwrapped "$@"
    '' else ''
      exec ${dns-update-pihole-unwrapped}/bin/dns-update-pihole-unwrapped "$@"
    ''
  );

  ping-uptime-kuma = (pkgs.writeShellScriptBin "ping-uptime-kuma@dns-resolution" ''
    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    source "${config.home.homeDirectory}/.config/sops-nix/secrets/uptime-kuma.env"

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
    source "${config.home.homeDirectory}/.config/sops-nix/secrets/dns-resolution.env"

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
    set -a
    source "${config.home.homeDirectory}/.config/sops-nix/secrets/dns-resolution.env"
    set +a

    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1
    export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
    export PYTHONPATH=${./routers}:$PYTHONPATH

    ${pythonEnv}/bin/python3 ${./routers/fetch_routers.py}
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
      # FIXME: This doesn't work as it looks like docker-pihole.service runs as a system level
      # service but dns-resolution works on user level. User service maybe is not dependable
      # on system service from here.
      # Requires = [ "docker-pihole.service" ];
      RequiresMountsFor = [ "/media/HOMELAB_MEDIA/services/pihole" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${dns-update-pihole}/bin/dns-update-pihole";
      ExecStopPost = "${ping-uptime-kuma}/bin/ping-uptime-kuma@dns-resolution";
      # Environment variables are set by the wrapper script
    };
  };

  systemd.user.timers.dns-resolution = {
    Unit = {
      Description = "Periodically update Pi-hole DNS entries with current network devices";
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "180m";
      Unit = "dns-resolution.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
