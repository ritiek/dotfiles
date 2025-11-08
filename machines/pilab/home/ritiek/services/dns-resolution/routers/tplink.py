import asyncio
import json
import os
import socket
from typing import List, Dict, Optional
from base import BaseRouter

try:
    from playwright.async_api import async_playwright
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False


class TPLinkRouter(BaseRouter):
    def __init__(self):
        super().__init__("TP-Link")
        self.router_ip = os.environ.get('TPLINK_ROUTER_IP', '192.168.2.1')
        self.password = os.environ.get('TPLINK_ROUTER_PASSWORD')
        self.clients = {"wireless": [], "wired": []}

    def is_available(self) -> bool:
        """Check if router is accessible"""
        if not PLAYWRIGHT_AVAILABLE:
            print("Playwright not available - TP-Link router disabled")
            return False

        if not self.password:
            print("Error: TPLINK_ROUTER_PASSWORD environment variable not set")
            return False

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.router_ip, 80))
            sock.close()
            return result == 0
        except Exception as e:
            print(f"TP-Link router connectivity check failed: {e}")
            return False

    async def login(self, page):
        """Login to router admin interface"""
        print(f"Navigating to TP-Link router at {self.router_ip}...")
        await page.goto(f"http://{self.router_ip}")

        await page.wait_for_selector('input[type="password"]')
        await page.fill('input[type="password"]', self.password)
        await page.click('button:has-text("Log in")')

        try:
            await page.wait_for_selector('#confirm-yes', timeout=3000)
            await page.click('#confirm-yes')
        except:
            pass

        await page.wait_for_timeout(5000)
        print("Successfully logged into TP-Link router!")

    async def extract_wireless_clients(self, page):
        """Extract wireless client information"""
        print("Extracting wireless clients from TP-Link router...")
        await page.click('#map_wireless:has-text("Wireless Clients")')
        await page.wait_for_timeout(5000)

        tables = await page.query_selector_all('table')
        client_table = None

        for table in tables:
            try:
                rows = await table.query_selector_all('tbody tr')
                for row in rows:
                    cells = await row.query_selector_all('td')
                    if len(cells) >= 7:
                        ip_text = await cells[2].text_content()
                        mac_text = await cells[3].text_content()

                        if ('192.168.2.' in ip_text and ':' in mac_text and ip_text != '192.168.2.1'):
                            client_table = table
                            break
                if client_table:
                    break
            except Exception:
                continue

        if not client_table:
            print("No wireless clients found in TP-Link router")
            return

        rows = await client_table.query_selector_all('tbody tr')

        for row in rows:
            cells = await row.query_selector_all('td')
            if len(cells) >= 7:
                name_input = await cells[1].query_selector('input')
                if name_input:
                    name = await name_input.input_value()
                else:
                    name = await cells[1].text_content()

                client = {
                    "id": await cells[0].text_content(),
                    "name": name,
                    "ip_address": await cells[2].text_content(),
                    "mac_address": await cells[3].text_content(),
                    "connection_type": await cells[4].text_content(),
                    "link_rate": await cells[5].text_content(),
                    "attached_to": await cells[6].text_content()
                }
                self.clients["wireless"].append(client)

        print(f"Found {len(self.clients['wireless'])} wireless clients")

    async def extract_wired_clients(self, page):
        """Extract wired client information"""
        print("Extracting wired clients from TP-Link router...")
        await page.click('#map_wire:has-text("Wired Clients")')
        await page.wait_for_timeout(5000)

        tables = await page.query_selector_all('table')
        client_table = None

        for table in tables:
            try:
                rows = await table.query_selector_all('tbody tr')
                for row in rows:
                    cells = await row.query_selector_all('td')
                    if len(cells) >= 7:
                        ip_text = await cells[2].text_content()
                        mac_text = await cells[3].text_content()
                        conn_type = await cells[4].text_content()

                        if ('192.168.2.' in ip_text and ':' in mac_text and ip_text != '192.168.2.1' and 'Wired' in conn_type):
                            client_table = table
                            break
                if client_table:
                    break
            except Exception:
                continue

        if not client_table:
            print("No wired clients found in TP-Link router")
            return

        rows = await client_table.query_selector_all('tbody tr')

        for row in rows:
            cells = await row.query_selector_all('td')
            if len(cells) >= 7:
                name_input = await cells[1].query_selector('input')
                if name_input:
                    name = await name_input.input_value()
                else:
                    name = await cells[1].text_content()

                client = {
                    "id": await cells[0].text_content(),
                    "name": name,
                    "ip_address": await cells[2].text_content(),
                    "mac_address": await cells[3].text_content(),
                    "connection_type": await cells[4].text_content(),
                    "link_rate": await cells[5].text_content(),
                    "attached_to": await cells[6].text_content()
                }
                self.clients["wired"].append(client)

        print(f"Found {len(self.clients['wired'])} wired clients")

    async def scan_clients(self):
        """Main method to scan all clients"""
        browsers_path = os.environ.get('PLAYWRIGHT_BROWSERS_PATH')
        launch_options = {
            'headless': True,
            'handle_sigterm': False,
            'handle_sighup': False
        }

        if browsers_path:
            browsers_json_path = os.path.join(browsers_path, 'browsers.json')
            if os.path.exists(browsers_json_path):
                with open(browsers_json_path, 'r') as f:
                    browsers = json.load(f)
                chromium_browsers = [b for b in browsers.get('browsers', []) if b['name'] == 'chromium']
                if chromium_browsers:
                    chromium_rev = chromium_browsers[0]['revision']
                    chromium_path = os.path.join(browsers_path, f'chromium-{chromium_rev}', 'chrome-linux', 'chrome')
                    launch_options['executable_path'] = chromium_path

        async with async_playwright() as p:
            browser = await p.chromium.launch(**launch_options)
            page = await browser.new_page()

            try:
                await self.login(page)
                await self.extract_wireless_clients(page)
                await self.extract_wired_clients(page)
            except Exception as e:
                print(f"Error during TP-Link scanning: {e}")
                raise
            finally:
                await browser.close()

    def get_clients(self) -> List[Dict[str, str]]:
        """Get clients from router in standardized format"""
        try:
            asyncio.run(self.scan_clients())

            clients = []

            for client in self.clients["wireless"]:
                standardized_client = {
                    "ip": client["ip_address"],
                    "mac": client["mac_address"],
                    "name": client["name"] if client["name"] else None,
                    "connection_type": client["connection_type"],
                    "link_rate": client["link_rate"]
                }
                if self.validate_client(standardized_client):
                    clients.append(standardized_client)

            for client in self.clients["wired"]:
                standardized_client = {
                    "ip": client["ip_address"],
                    "mac": client["mac_address"],
                    "name": client["name"] if client["name"] else None,
                    "connection_type": client["connection_type"],
                    "link_rate": client["link_rate"]
                }
                if self.validate_client(standardized_client):
                    clients.append(standardized_client)

            return clients

        except Exception as e:
            print(f"TP-Link client scanning failed: {e}")
            return []
