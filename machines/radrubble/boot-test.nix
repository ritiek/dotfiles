# Boot a new generation once, falling back to the current one on failure.
#   deploy with `nixos-rebuild boot`, then on radrubble: sudo boot-test
# The test boot puts extlinux DEFAULT back to the previous generation as soon
# as userspace starts, and reboots after 10 min unless confirmed with:
#   sudo boot-test keep
# A kernel hang before userspace still needs a power cycle + SD card fix
# (U-Boot doesn't arm the watchdog on a cold boot).
{ pkgs, ... }:

let
  conf = "/boot/extlinux/extlinux.conf";
  boot-test = pkgs.writeShellApplication {
    name = "boot-test";
    runtimeInputs = with pkgs; [ coreutils gnused gawk systemd ];
    text = ''
      if [ "''${1:-}" = keep ]; then
        touch /run/boot-test-ok
        sed -i 's/^DEFAULT .*/DEFAULT nixos-default/' ${conf}
        sync
        exit 0
      fi
      booted=$(readlink -f /run/booted-system)
      label=$(awk -v init="$booted/init" '
        /^LABEL nixos-[0-9]+-/ { l = $2 }
        /APPEND/ && index($0, init) && l { print l; exit }
      ' ${conf})
      [ -n "$label" ] || { echo "no extlinux entry for $booted" >&2; exit 1; }
      echo "fallback: $label"
      echo "$label" > /boot/boot-test-fallback
      sync
      systemctl reboot
    '';
  };
in
{
  environment.systemPackages = [ boot-test ];

  systemd.services.boot-test-guard = {
    description = "Revert extlinux default and reboot unless the test boot is confirmed";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    unitConfig.ConditionPathExists = "/boot/boot-test-fallback";
    path = with pkgs; [ coreutils gnused systemd ];
    script = ''
      sed -i "s/^DEFAULT .*/DEFAULT $(cat /boot/boot-test-fallback)/" ${conf}
      mv /boot/boot-test-fallback /run/boot-test-fallback
      sync
      sleep 600
      [ -e /run/boot-test-ok ] || systemctl reboot
    '';
  };
}
