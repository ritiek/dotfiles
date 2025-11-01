#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
BASEDIR="$SCRIPT_DIR/mnt-usb"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <disk-device> [--write-efi-boot-entries]"
    echo "Example: $0 /dev/disk/by-id/usb-SanDisk_Ultra_...-0:0"
    echo ""
    echo "Available disks:"
    lsblk -o NAME,SIZE,MODEL,SERIAL
    exit 1
fi

DISK_DEVICE="$1"
EXTRA_ARGS="${2:-}"

if [ ! -b "$DISK_DEVICE" ]; then
    echo "Error: Disk device $DISK_DEVICE does not exist or is not a block device"
    exit 1
fi

echo "WARNING: This will DESTROY all data on $DISK_DEVICE"
echo "Disk info:"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK_DEVICE"
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

read -s -p "Enter LUKS passphrase: " passphrase
echo
read -s -p "Confirm LUKS passphrase: " passphrase2
echo

if [ "$passphrase" != "$passphrase2" ]; then
    echo "Error: Passphrases do not match"
    exit 1
fi

rm -rf "$BASEDIR"
mkdir -p "$BASEDIR"

echo "Setting up pre-installation files..."

mkdir -p "$BASEDIR/nix/persist/system"
systemd-machine-id-setup --root="$BASEDIR/nix/persist/system/"

mkdir -p "$BASEDIR/nix/persist/system/etc/ssh/"

echo "Decrypting mishy SSH host keys from secrets.yaml..."
nix run nixpkgs#sops -- decrypt "$SCRIPT_DIR/../../machines/secrets.yaml" \
  --extract '["mishy_ssh_host_ed25519_key"]' \
  --output "$BASEDIR/nix/persist/system/etc/ssh/ssh_host_ed25519_key"

chmod 600 "$BASEDIR/nix/persist/system/etc/ssh/ssh_host_ed25519_key"

ssh-keygen -y -f \
  "$BASEDIR/nix/persist/system/etc/ssh/ssh_host_ed25519_key" \
  > "$BASEDIR/nix/persist/system/etc/ssh/ssh_host_ed25519_key.pub"

echo "Copying NixOS configuration..."
mkdir -p "$BASEDIR/nix/persist/system/etc/nixos"
rsync -rl \
  --exclude '*/mnt*' \
  --exclude '*/.git' \
  "$SCRIPT_DIR/../../" \
  "$BASEDIR/nix/persist/system/etc/nixos/"

echo "$passphrase" > /tmp/disk.key
chmod 600 /tmp/disk.key

echo ""
echo "Running disko-install..."
echo "This will partition and format $DISK_DEVICE, then install NixOS."
echo ""

DISKO_CMD="nix run 'github:nix-community/disko/latest#disko-install' -- \
  --flake '$SCRIPT_DIR/../../#mishy-usb' \
  --disk main '$DISK_DEVICE'"

if [ "$EXTRA_ARGS" = "--write-efi-boot-entries" ]; then
    DISKO_CMD="$DISKO_CMD --write-efi-boot-entries"
fi

eval "sudo $DISKO_CMD"

rm -f /tmp/disk.key

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Reboot and select the USB drive in your boot menu"
echo "2. Enter your LUKS passphrase at boot"
echo "3. Log in as ritiek (password is empty, configure it!)"
echo "4. Run: sudo nixos-rebuild switch --flake /etc/nixos#mishy-usb"
echo ""
echo "Note: The system uses impermanence with tmpfs root."
echo "Only files in /nix/persist/ will survive reboots."