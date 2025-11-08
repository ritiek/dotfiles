import urllib.request
import urllib.parse
import http.cookiejar
import re
import os
import socket
from typing import List, Dict, Optional, Tuple
from base import BaseRouter


class ARPRouter(BaseRouter):
    def __init__(self):
        super().__init__("ARP-Scrape")
        self.router_host = os.environ.get('ROUTER_HOST')
        if not self.router_host:
            raise ValueError("ROUTER_HOST environment variable not set")

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

    def is_available(self) -> bool:
        """Check if router is accessible"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.router_ip, int(self.router_port)))
            sock.close()
            return result == 0
        except Exception as e:
            print(f"Router connectivity check failed: {e}")
            return False

    def authenticate(self) -> bool:
        """Authenticate with router"""
        username = os.environ.get('ROUTER_USERNAME')
        password_hash = os.environ.get('ROUTER_PASSWORD_HASH')

        if not username or not password_hash:
            print("Error: Router credentials not found")
            return False

        print(f"Authenticating with ARP router at {self.router_base_url}...")

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
                arp_url = f"{self.router_base_url}/arptable.asp?v=1759053170000"
                req = urllib.request.Request(arp_url)
                response = self.opener.open(req, timeout=10)
                response_text = response.read().decode('utf-8')

                if "ARP Table" in response_text or "User List" in response_text:
                    print("ARP router authentication successful")
                    return True
            return False
        except Exception as e:
            print(f"Router authentication failed: {e}")
            return False

    def fetch_arp_table(self) -> Optional[str]:
        """Fetch ARP table HTML"""
        arp_url = f"{self.router_base_url}/arptable.asp?v=1759053170000"

        try:
            req = urllib.request.Request(arp_url)
            response = self.opener.open(req, timeout=10)
            if response.getcode() == 200:
                return response.read().decode("utf-8")
        except Exception as e:
            print(f"Error fetching ARP table: {e}")
        return None

    def parse_arp_table(self, arp_html: str) -> List[Tuple[str, str]]:
        """Parse ARP table HTML to extract IP/MAC pairs"""
        entries = []
        pattern = r'<td>([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s+</td><td>([a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2}-[a-fA-F0-9]{2})\s+</td>'

        matches = re.findall(pattern, arp_html)

        for ip, mac in matches:
            mac_formatted = mac.upper().replace("-", ":")
            entries.append((ip, mac_formatted))

        return entries

    def get_clients(self) -> List[Dict[str, str]]:
        """Get clients from router in standardized format"""
        if not self.authenticate():
            return []

        arp_html = self.fetch_arp_table()
        if not arp_html:
            return []

        arp_entries = self.parse_arp_table(arp_html)

        clients = []
        for ip, mac in arp_entries:
            client = {
                "ip": ip,
                "mac": mac,
                "name": None,
                "connection_type": "unknown",
                "link_rate": "unknown"
            }
            if self.validate_client(client):
                clients.append(client)

        return clients
