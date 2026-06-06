#!/usr/bin/env python3
"""
Verify a YubiKey HMAC-OTP and derive a stable LUKS passphrase.

Derived key:
  LUKS_KEY = HMAC-SHA256(key=SECRET_KEY_bytes, msg=PRIVATE_ID_bytes).hexdigest()

This key is NEVER stored anywhere — computed on-the-fly after OTP verification.

Environment variables:
  HOMELAB_OTP         - Full user input: "<pin_prefix><PUBLIC_ID><token_modhex>"
  YUBIKEY_PIN_PREFIX  - PIN prefix the user types before pressing YubiKey (e.g. "Something")
  YUBIKEY_PRIVATE_ID  - 6-byte private identity (hex)
  YUBIKEY_SECRET_KEY  - 16-byte AES key (hex)

Exit 0 on success (prints derived LUKS key to stdout), exit 1 on failure.
"""

import hmac
import hashlib
import os
import sys
from Crypto.Cipher import AES

PUBLIC_ID = "nbdcllnhurcl"  # Not sensitive - visible in every OTP


def crc16(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0x8408
            else:
                crc >>= 1
    return crc


def modhex_decode(s: str) -> bytes:
    table = "cbdefghijklnrtuv"
    result = []
    for i in range(0, len(s), 2):
        hi = table.index(s[i])
        lo = table.index(s[i + 1])
        result.append((hi << 4) | lo)
    return bytes(result)


def verify_and_derive(yubikey_otp: str, private_id_hex: str, secret_key_hex: str) -> str:
    if not yubikey_otp.startswith(PUBLIC_ID):
        sys.stderr.write("ERROR: OTP does not start with expected public ID\n")
        sys.exit(1)

    token_modhex = yubikey_otp[len(PUBLIC_ID):]
    if len(token_modhex) != 32:
        sys.stderr.write(f"ERROR: Token portion has unexpected length {len(token_modhex)}, expected 32\n")
        sys.exit(1)

    key_bytes = bytes.fromhex(secret_key_hex)
    plaintext = AES.new(key_bytes, AES.MODE_ECB).decrypt(modhex_decode(token_modhex))

    if crc16(plaintext) != 0xF0B8:
        sys.stderr.write("ERROR: CRC check failed (wrong secret key or corrupted OTP)\n")
        sys.exit(1)

    if plaintext[:6].hex() != private_id_hex.lower():
        sys.stderr.write("ERROR: Private ID mismatch\n")
        sys.exit(1)

    # Derive stable LUKS passphrase from fixed YubiKey internals
    # HMAC-SHA256(key=SECRET_KEY_bytes, msg=PRIVATE_ID_bytes)
    private_id_bytes = bytes.fromhex(private_id_hex)
    derived = hmac.new(key_bytes, private_id_bytes, hashlib.sha256).hexdigest()
    return derived


def main():
    homelab_otp = os.environ.get("HOMELAB_OTP", "")
    pin_prefix = os.environ.get("YUBIKEY_PIN_PREFIX", "")
    private_id = os.environ.get("YUBIKEY_PRIVATE_ID", "")
    secret_key = os.environ.get("YUBIKEY_SECRET_KEY", "")

    if not all([homelab_otp, private_id, secret_key]):
        sys.stderr.write("ERROR: Missing required environment variables (HOMELAB_OTP, YUBIKEY_PRIVATE_ID, YUBIKEY_SECRET_KEY)\n")
        sys.exit(1)

    # HOMELAB_OTP = what user types in HA reply: "<pin_suffix><PUBLIC_ID><token_modhex>"
    # Prepend pin_prefix internally (user never types it), then locate PUBLIC_ID
    full_token = (pin_prefix + homelab_otp).lower()
    public_id_lower = PUBLIC_ID.lower()
    idx = full_token.find(public_id_lower)
    if idx == -1:
        sys.stderr.write("ERROR: PUBLIC_ID not found in token\n")
        sys.exit(1)

    yubikey_otp = full_token[idx:]

    derived_key = verify_and_derive(yubikey_otp, private_id, secret_key)
    print(derived_key)


if __name__ == "__main__":
    main()
