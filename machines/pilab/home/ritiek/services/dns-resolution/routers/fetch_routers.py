#!/usr/bin/env python3
import sys
import os
import json

sys.path.insert(0, os.path.dirname(__file__))

from airtel import AirtelRouter
from tplink import TPLinkRouter
from arpscrape import ARPRouter

CONFIG_FILE = os.path.expanduser("/media/HOMELAB_MEDIA/services/pihole/dns-resolution.json")

def load_config():
    """Load MAC to hostname mapping from JSON file"""
    try:
        with open(CONFIG_FILE, "r") as f:
            mac_to_hostname = json.load(f)
        print(f"Loaded {len(mac_to_hostname)} MAC to hostname mappings from {CONFIG_FILE}\n")
        return mac_to_hostname
    except FileNotFoundError:
        print(f"Warning: Config file {CONFIG_FILE} not found, using router names\n")
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing config file: {e}, using router names\n")
        return {}

def main():
    mac_to_hostname = load_config()
    routers = []

    try:
        airtel = AirtelRouter()
        if airtel.is_available():
            routers.append(('Airtel', airtel))
    except Exception as e:
        print(f"Skipping Airtel router: {e}")

    try:
        tplink = TPLinkRouter()
        if tplink.is_available():
            routers.append(('TP-Link', tplink))
    except Exception as e:
        print(f"Skipping TP-Link router: {e}")

    try:
        arpscrape = ARPRouter()
        if arpscrape.is_available():
            routers.append(('ARP Scrape', arpscrape))
    except Exception as e:
        print(f"Skipping ARP Scrape router: {e}")

    if not routers:
        print("No routers available")
        return 1

    for name, router in routers:
        print(f"\n{'='*80}")
        print(f"Fetching clients from {name} router...")
        print('='*80)

        try:
            clients = router.get_clients()

            if not clients:
                print(f"No clients found from {name}")
                continue

            print(f"\nFound {len(clients)} clients from {name}:\n")
            print(f"{'IP Address':<15} {'MAC Address':<18} {'Hostname':<25} {'Connection':<15} {'Link Rate'}")
            print('-'*80)

            for client in clients:
                ip = client.get('ip', '')
                mac = client.get('mac', '')
                hostname = mac_to_hostname.get(mac.upper(), '')
                conn_type = client.get('connection_type', '')
                link_rate = client.get('link_rate', '')

                print(f"{ip:<15} {mac:<18} {hostname:<25} {conn_type:<15} {link_rate}")

        except Exception as e:
            print(f"Error fetching clients from {name}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\n{'='*80}\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
