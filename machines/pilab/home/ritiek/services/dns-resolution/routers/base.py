from abc import ABC, abstractmethod
from typing import List, Dict, Optional


class BaseRouter(ABC):
    def __init__(self, name: str):
        self.name = name

    @abstractmethod
    def get_clients(self) -> List[Dict[str, str]]:
        """Return list of clients with standardized format:
        [
            {
                "ip": "192.168.1.100",      # Required
                "mac": "aa:bb:cc:dd:ee:ff", # Required
                "name": "device-name",       # Optional
                "connection_type": "wireless", # Optional
                "link_rate": "1300 Mbps"     # Optional
            }
        ]
        """
        pass

    @abstractmethod
    def is_available(self) -> bool:
        """Check if router is accessible"""
        pass

    def validate_client(self, client: Dict[str, str]) -> bool:
        """Validate client data format"""
        required_fields = ['ip', 'mac']
        return all(field in client for field in required_fields)
