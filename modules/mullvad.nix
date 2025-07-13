{ config, lib, pkgs, ... }:
{
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  environment.systemPackages = with pkgs; [
    nftables
  ];

  # Override Mullvad service to add our rules.
  systemd.services.mullvad-daemon = {
    after = lib.mkAfter (lib.optional config.services.tailscale.enable "tailscaled.service");

    postStart = lib.mkAfter (let
      mullvad = config.services.mullvad-vpn.package;
    in ''
      # Allow a buffer period for Mullvad to load up.
      ${pkgs.coreutils}/bin/sleep 5s

      ${lib.optionalString config.services.tailscale.enable ''
        echo "Applying Tailscale nftables rules"
        # Apply nftables rules to allow Tailscale traffic through.
        # Refer to https://theorangeone.net/posts/tailscale-mullvad/ and thanks!
        ${pkgs.nftables}/bin/nft -f ${pkgs.writeText "mullvad_tailscale.conf" ''
          table inet mullvad_tailscale {
            chain output {
              type route hook output priority 0; policy accept;
              ip daddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
            }
          }
        ''}
      ''}

      while ! ${mullvad}/bin/mullvad status >/dev/null; do sleep 1; done

      # ${mullvad}/bin/mullvad tunnel ipv6 set on
      # ${mullvad}/bin/mullvad set default \
      #     --block-ads --block-trackers --block-malware
      # ${mullvad}/bin/mullvad relay set tunnel wireguard --use-multihop on

      ${mullvad}/bin/mullvad auto-connect set off
      ${mullvad}/bin/mullvad lan set allow
      ${lib.optionalString config.services.tailscale.enable ''
        ${mullvad}/bin/mullvad dns set custom 100.100.100.100
      ''}
      ${mullvad}/bin/mullvad lockdown-mode set off
    '');

    preStop = lib.mkAfter ''
      ${lib.optionalString config.services.tailscale.enable ''
        ${pkgs.nftables}/bin/nft delete table inet mullvad_tailscale 2>/dev/null || true
      ''}
    '';
  };
}
