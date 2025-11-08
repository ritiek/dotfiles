"""
Router client scrapers for DNS resolution.

This package provides modular router implementations for scraping
client information from different types of routers.
"""

from base import BaseRouter
from arpscrape import ARPRouter
from tplink import TPLinkRouter
from airtel import AirtelRouter

__all__ = ['BaseRouter', 'ARPRouter', 'TPLinkRouter', 'AirtelRouter']
