#!/usr/bin/env bash
# Push switchwrt's secrets to the device at runtime.
#
# switchwrt is an OpenWrt image, not a nixosConfiguration, so sops-nix cannot
# deploy its secrets: the OpenWrt buildroot has no sops or age binary, and the
# image itself lives in the world-readable /nix/store, so anything baked into
# its rootfs leaks. Instead the image ships only logic, and this script
# decrypts machines/switchwrt/secrets.yaml here on the operator's machine and
# pipes the values over ssh into /usr/sbin/switchwrt-apply-secrets on the
# device. Secrets touch RAM on both ends and never the filesystem on either --
# unlike machines/clawsiecats/anywhere.sh and machines/mishy/install-usb.sh,
# which are forced to stage real files because nixos-anywhere --extra-files
# and disko-install need them. ssh takes a pipe, so we need no staging dir.
#
# Run this after every reflash. It is idempotent, so re-running to rotate a
# single secret is fine.
#
# Usage:
#   ./machines/switchwrt/deploy-secrets.sh [user@host]
#
# Example:
#   ./machines/switchwrt/deploy-secrets.sh              # root@192.168.3.1
#   ./machines/switchwrt/deploy-secrets.sh root@100.64.0.21
#
# Prefer the LAN address (192.168.3.1, reachable over eth0 or the AP) or the
# tailnet address. Both are encrypted transports; so is the WAN-side address,
# but it changes every boot because randomize-wwan-mac draws a fresh DHCP
# lease each time.

set -euo pipefail

# Deliberately NO `set -x` anywhere in this script, unlike anywhere.sh: every
# value it handles is secret, and tracing would print all of them. Same reason
# anywhere.sh drops back to `set +x` around its passphrase prompt.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS="$SCRIPT_DIR/secrets.yaml"
TARGET="${1:-root@192.168.3.1}"

if [ ! -f "$SECRETS" ]; then
	echo "error: $SECRETS not found" >&2
	exit 1
fi

# Keys in secrets.yaml are flat top-level names containing literal dots, not
# nested maps, so extraction is single-level: '["tailscale.authkey"]'.
sops_get() {
	nix run nixpkgs#sops -- decrypt "$SECRETS" --extract "[\"$1\"]"
}

echo "Decrypting $SECRETS (this may prompt for a YubiKey touch)..."

# Command substitution strips trailing newlines, which is what we want: the
# stored values are bare tokens and the device writes them back without a
# trailing newline.
tailscale_authkey="$(sops_get 'tailscale.authkey')"
netbird_setupkey="$(sops_get 'netbird.setupkey')"
wifi_ap_psk="$(sops_get 'wifi.ap_psk')"
root_password_hash="$(sops_get 'root.password_hash')"

# The wire protocol is one key=value per line, so a value containing a newline
# would silently corrupt the payload. None of ours should.
for name in tailscale_authkey netbird_setupkey wifi_ap_psk root_password_hash; do
	value="${!name}"
	if [ -z "$value" ]; then
		echo "error: $name decrypted empty" >&2
		exit 1
	fi
	if [ "$value" != "${value%%$'\n'*}" ]; then
		echo "error: $name contains a newline, which the key=value payload cannot carry" >&2
		exit 1
	fi
done

# Catch the yescrypt trap before it reaches the device: LuCI authenticates via
# rpcd, which calls crypt() from musl libc, and musl implements $1$/$5$/$6$/
# $2b$ but not yescrypt. A $y$ hash would be written happily and then fail
# every LuCI and console login. Generate with:
#   nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512
case "$root_password_hash" in
	'$6$'*) ;;
	*)
		echo "error: root.password_hash is not a \$6\$ (sha512) hash" >&2
		echo "       musl's crypt() cannot verify anything else; LuCI login would break." >&2
		exit 1
		;;
esac

echo "Sending to $TARGET..."

# One ssh invocation, one payload, straight into the helper's stdin. The
# values never appear in argv on either side.
printf 'tailscale_authkey=%s\nnetbird_setupkey=%s\nwifi_ap_psk=%s\nroot_password_hash=%s\n' \
	"$tailscale_authkey" \
	"$netbird_setupkey" \
	"$wifi_ap_psk" \
	"$root_password_hash" |
	ssh "$TARGET" switchwrt-apply-secrets

cat <<'EOF'

Done. Next steps:

  1. Check what the device did:
       ssh root@192.168.3.1 'logread -e apply-secrets'

  2. Confirm the AP came up and is no longer disabled:
       ssh root@192.168.3.1 'iwinfo wlan0 info; uci get wireless.default_radio0.disabled'

  3. Confirm tailscale registered (expect 100.64.0.21):
       ssh root@192.168.3.1 'tailscale ip -4'

  4. Confirm the root password works, in LuCI (http://192.168.3.1) and on the
     serial console. SSH is key-only and unaffected either way, so a bad hash
     is always recoverable.

  5. Join an upstream WiFi network for the wwan uplink, if you want the second
     path. LuCI -> Network -> Wireless -> Scan -> Join on radio1; nothing is
     preconfigured, by design.

To rotate any secret later, edit sops and re-run this script -- no rebuild:

       sops machines/switchwrt/secrets.yaml
       ./machines/switchwrt/deploy-secrets.sh
EOF
