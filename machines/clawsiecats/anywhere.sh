#!/usr/bin/env sh

# Usage:
# $ ./machines/clawsiecats/anywhere.sh .#clawsiecats root@12.121.212.121
# Luks with disko:
# $ ./machines/clawsiecats/anywhere.sh .#clawsiecats root@12.121.212.121 --luks

set -x
BASEDIR=$(dirname "$0")/mnt

# Start from clean slate.
rm -rf "$BASEDIR"

# Initrd SSH key for LUKS (if using it).
install -d -m755 "$BASEDIR"/boot/
ssh-keygen -t ed25519 -a 100 -N "" -f "$BASEDIR"/boot/ssh_host_ed25519_key

# Machine ID.
systemd-machine-id-setup --root="$BASEDIR"/nix/persist/system/

# Host SSH keys; also used by sops-nix for decrypting secrets.
install -d -m755 "$BASEDIR"/nix/persist/system/etc/ssh/
nix run nixpkgs#sops -- decrypt ./machines/secrets.yaml \
  --extract '["clawsiecats_ssh_host_ed25519_key"]' \
  --output "$BASEDIR"/nix/persist/system/etc/ssh/ssh_host_ed25519_key
chmod 600 "$BASEDIR"/nix/persist/system/etc/ssh/ssh_host_ed25519_key
ssh-keygen -y -f \
  "$BASEDIR"/nix/persist/system/etc/ssh/ssh_host_ed25519_key \
  > "$BASEDIR"/nix/persist/system/etc/ssh/ssh_host_ed25519_key.pub

# Transfer current state of `/etc/nixos/` to the new installation.
rsync -rl \
  --exclude '*/mnt' \
  "$BASEDIR"/../../../ \
  "$BASEDIR"/nix/persist/system/etc/nixos/

if [ "$3" = "--luks" ]; then
    read -s -p "Enter LUKS passphrase: " passphrase
    # Do not log the passphrase on console!
    set +x
    nix run github:nix-community/nixos-anywhere -- \
      --extra-files "$BASEDIR" \
      --flake "$1" "$2" \
      --disk-encryption-keys /tmp/disk.key <(echo "$passphrase")
    set -x
    exit 0
fi

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$BASEDIR" \
  --flake "$1" "$2"
  # -i <(ssh-add -L | head -1) \
  # --phases kexec,disko,install \
  # --flake .#clawsiecats root@12.121.212.121
