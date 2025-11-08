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


class AirtelRouter(BaseRouter):
    def __init__(self):
        super().__init__("Airtel")
        # Support both AIRTEL_ROUTER_IP and AIRTEL_ROUTER_HOST
        router_host = os.environ.get('AIRTEL_ROUTER_HOST') or os.environ.get('AIRTEL_ROUTER_IP', '192.168.1.1')
        # Extract IP from host:port format if present
        if ':' in router_host:
            self.router_ip = router_host.split(':')[0]
        else:
            self.router_ip = router_host

        self.username = os.environ.get('AIRTEL_ROUTER_USERNAME', 'admin')
        # Support both AIRTEL_ROUTER_PASSWORD and AIRTEL_ROUTER_PASSWORD_HASH
        self.password = os.environ.get('AIRTEL_ROUTER_PASSWORD') or os.environ.get('AIRTEL_ROUTER_PASSWORD_HASH')
        self.clients = []

    def is_available(self) -> bool:
        """Check if router is accessible"""
        if not PLAYWRIGHT_AVAILABLE:
            print("Playwright not available - Airtel router disabled")
            return False

        if not self.password:
            print("Error: AIRTEL_ROUTER_PASSWORD environment variable not set")
            return False

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.router_ip, 443))
            sock.close()
            return result == 0
        except Exception as e:
            print(f"Airtel router connectivity check failed: {e}")
            return False

    async def login(self, page):
        """Login to Airtel router admin interface"""
        print(f"Navigating to Airtel router at {self.router_ip}...")
        try:
            await page.goto(f"https://{self.router_ip}/web_whw/#/login", timeout=60000)
            print("Page loaded, waiting for login form...")
            await page.wait_for_selector('input[name="value"]', timeout=30000)

            print(f"Logging in as {self.username}...")
            inputs = await page.query_selector_all('input[name="value"]')
            await inputs[0].fill(self.username)
            await inputs[1].fill(self.password)

            await page.wait_for_timeout(500)

            login_button = await page.query_selector('button[type="submit"], button:has-text("Login"), button:has-text("login"), .login-button')
            if login_button:
                print("Found login button, clicking it...")
                await login_button.click()
            else:
                print("No login button found, pressing Enter...")
                await inputs[1].press('Enter')

            try:
                await page.wait_for_url(lambda url: "login" not in url.lower(), timeout=15000)
                print(f"Login successful! Current URL: {page.url}")
            except Exception:
                current_url = page.url
                print(f"Warning: Still on login page after 15s. URL: {current_url}")

                error_elements = await page.query_selector_all('.error, .alert, [class*="error"], [class*="alert"]')
                if error_elements:
                    error_texts = []
                    for elem in error_elements:
                        text = await elem.text_content()
                        if text and text.strip():
                            error_texts.append(text.strip())
                    if error_texts:
                        print(f"Error messages found: {error_texts}")
                        raise Exception(f"Login failed: {', '.join(error_texts)}")

                raise Exception("Login failed - still on login page after timeout")

            print("Successfully logged into Airtel router!")
        except Exception as e:
            print(f"Login error: {e}")
            import traceback
            traceback.print_exc()
            raise

    async def extract_clients(self, page):
        """Extract client information from Airtel router"""
        print("Extracting clients from Airtel router...")
        try:
            await page.goto(f"https://{self.router_ip}/web_whw/#/devices", timeout=30000)
            print("Devices page loaded, waiting for table...")

            try:
                await page.wait_for_selector('table tbody tr', timeout=15000)
                print("Table found!")
            except Exception as e:
                print(f"Table not found after 15s: {e}")

                page_content = await page.content()
                print(f"Page content length: {len(page_content)}")
                with open('/tmp/airtel_devices_page.html', 'w') as f:
                    f.write(page_content)
                print("Page HTML saved to /tmp/airtel_devices_page.html")

                tables = await page.query_selector_all('table')
                print(f"Number of tables found: {len(tables)}")

                current_url = page.url
                print(f"Current URL: {current_url}")
                if "login" in current_url.lower():
                    raise Exception("Session expired or login failed - redirected to login page")

                raise

            await page.wait_for_timeout(2000)

            self.clients = await page.evaluate('''
                () => {
                    const devices = [];
                    document.querySelectorAll('table tbody tr').forEach((row) => {
                        const cells = row.querySelectorAll('td');
                        if (cells.length >= 7) {
                            const name = cells[0].textContent.trim();
                            if (name && name !== 'Device name') {
                                const ipv4Cell = cells[5].textContent.trim();
                                const ipv4Match = ipv4Cell.match(/(\\d+\\.\\d+\\.\\d+\\.\\d+)/);
                                const leaseMatch = ipv4Cell.match(/Remaining lease time: (.+)/);

                                devices.push({
                                    name: name,
                                    signal: cells[1].textContent.trim(),
                                    connectedTo: cells[2].textContent.trim(),
                                    network: cells[3].textContent.trim(),
                                    mac: cells[4].textContent.trim(),
                                    ipv4: ipv4Match ? ipv4Match[1] : '',
                                    leaseTime: leaseMatch ? leaseMatch[1] : '',
                                    ipv6: cells[6].textContent.trim()
                                });
                            }
                        }
                    });
                    return devices;
                }
            ''')

            print(f"Found {len(self.clients)} clients")
        except Exception as e:
            print(f"Extract clients error: {e}")
            import traceback
            traceback.print_exc()
            raise

    async def scan_clients(self):
        """Main method to scan all clients"""
        browsers_path = os.environ.get('PLAYWRIGHT_BROWSERS_PATH')
        launch_options = {
            'headless': True,
            'handle_sigterm': False,
            'handle_sighup': False,
            'args': [
                '--disable-web-security',
                '--ignore-certificate-errors',
                '--no-sandbox'
            ]
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
            page = await browser.new_page(ignore_https_errors=True)

            try:
                await self.login(page)
                await self.extract_clients(page)
            except Exception as e:
                print(f"Error during Airtel scanning: {e}")
                raise
            finally:
                await browser.close()

    def get_clients(self) -> List[Dict[str, str]]:
        """Get clients from router in standardized format"""
        try:
            asyncio.run(self.scan_clients())

            standardized_clients = []

            for client in self.clients:
                standardized_client = {
                    "ip": client["ipv4"],
                    "mac": client["mac"],
                    "name": client["name"] if client["name"] else None,
                    "connection_type": client["network"],
                    "link_rate": client["signal"] if client["signal"] else None
                }
                if self.validate_client(standardized_client):
                    standardized_clients.append(standardized_client)

            return standardized_clients

        except Exception as e:
            print(f"Airtel client scanning failed: {e}")
            return []
