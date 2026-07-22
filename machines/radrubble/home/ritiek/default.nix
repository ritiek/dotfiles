{ config, pkgs, inputs, everythingElsePath, ... }:
let
  # Nixarr's per-service systemd unit names (seerr.service, not
  # jellyseerr.service; qui.service is a separate WebUI proxy unit alongside
  # qbittorrent.service). Keep in sync with machines/radrubble/services/nixarr.nix.
  units = "radarr.service sonarr.service bazarr.service prowlarr.service qbittorrent.service qui.service jellyfin.service seerr.service";

  mediaserver-mount = pkgs.writeShellScriptBin "mediaserver-mount" ''
    set -x

    # Mount EVERYTHING_ELSE partition only if not already mounted. No OTP
    # support here (unlike pilab's homelab-mount) -- always prompts
    # interactively for the LUKS passphrase.
    if ! mountpoint -q ${everythingElsePath}; then
      if [ ! -e /dev/mapper/EVERYTHING_ELSE ]; then
        cryptsetup open \
          /dev/disk/by-label/EVERYTHING_ELSE \
          EVERYTHING_ELSE
      fi
      mount -o defaults,noatime,nodiscard,noautodefrag,ssd,space_cache=v2,compress-force=zstd:3 \
        /dev/mapper/EVERYTHING_ELSE \
        ${everythingElsePath}
    fi

    # systemd-tmpfiles-setup.service only runs once at boot, before
    # EVERYTHING_ELSE is mounted, so the ownership fixups declared in
    # services/nixarr.nix's systemd.tmpfiles.rules never ran against the
    # migrated data. Re-trigger them now that the drive is mounted.
    ${pkgs.systemd}/bin/systemd-tmpfiles --create
  '';

  mediaserver-start = pkgs.writeShellScriptBin "mediaserver-start" ''
    set -x
    mediaserver-mount && systemctl start ${units}
  '';

  mediaserver-stop = pkgs.writeShellScriptBin "mediaserver-stop" ''
    set -x
    systemctl stop ${units}
  '';

  mediaserver-unmount = pkgs.writeShellScriptBin "mediaserver-unmount" ''
    set -x

    # Unmount EVERY mountpoint backed by EVERYTHING_ELSE (deepest path
    # first). A bare "umount -l ${everythingElsePath}" would leave any
    # nested bind mounts referencing the device, so "cryptsetup close" would
    # loop forever on "Device or resource busy".
    mapper="/dev/mapper/EVERYTHING_ELSE"
    if [ -e "$mapper" ]; then
      ${pkgs.util-linux}/bin/findmnt -rno TARGET --source "$mapper" 2>/dev/null \
        | ${pkgs.gawk}/bin/awk '{ print length, $0 }' \
        | ${pkgs.coreutils}/bin/sort -rn \
        | ${pkgs.coreutils}/bin/cut -d" " -f2- \
        | while read -r mp; do
            umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
          done

      # Bounded retry in case a lazy unmount is still settling, instead of
      # letting cryptsetup spin on the device-mapper remove ioctl forever.
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        cryptsetup close EVERYTHING_ELSE && break
        sleep 1
      done
    fi
  '';
in
{
  imports = [
    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    # ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/shpool.nix
    ./../../../../modules/home/btop.nix
    ./../../../../modules/home/ssh.nix
    ./../../../../modules/home/opencode.nix
    ./../../../../modules/home/direnv.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: _prev: {
      unstable = import inputs.unstable {
        inherit (final) system;
        config.allowUnfree = true;
      };
    })
  ];

  home = {
    stateVersion = "24.11";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    packages = with pkgs; [
      any-nix-shell
      psmisc
      moreutils
      file

      unzip
      unrar-wrapper
      sd
      compsize
      lshw
      gdu

      iptables
      nmap
      dig
      cryptsetup
      openssl
      deploy-rs

      miniserve
      bore-cli
      iperf

      mediaserver-mount
      mediaserver-start
      mediaserver-stop
      mediaserver-unmount
    ];
  };

  programs = {
    command-not-found.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
  };
}
