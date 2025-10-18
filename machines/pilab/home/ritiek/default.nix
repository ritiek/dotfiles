{ config, pkgs, inputs, homelabMediaPath, everythingElsePath, enableLEDs, ...}:
let
  homelab-mount = (pkgs.writeShellScriptBin "homelab-mount" ''
    set -x

    # Mount HOMELAB_MEDIA partition only if not already mounted
    if ! mountpoint -q ${homelabMediaPath}; then
      if [ ! -e /dev/mapper/HOMELAB_MEDIA ]; then
        cryptsetup open \
          /dev/disk/by-label/HOMELAB_MEDIA \
          HOMELAB_MEDIA
      fi
      mount -o defaults,noatime,nodiscard,noautodefrag,ssd,space_cache=v2,compress-force=zstd:3 \
        /dev/mapper/HOMELAB_MEDIA \
        ${homelabMediaPath}
    fi

    # Mount EVERYTHING_ELSE partition only if not already mounted
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
  '');
in
{
  imports = [
    inputs.sops-nix.homeManagerModule

    ./gpio/bme680.nix
    ./services/spotdl.nix
    ./services/paperless-ngx.nix
    ./services/whatsapp-backup-verify.nix
    ./services/verify-sqlcipher-integrity.nix
    ./services/dns-resolution.nix
    ./../../../../scripts/home/immich-env.nix
    ./../../../../modules/home/sops.nix
    ./../../../../modules/home/nix.nix
    # ./../../../../modules/home/gnupg.nix
    ./../../../../modules/home/zsh
    ./../../../../modules/home/git
    ./../../../../modules/home/neovim
    ./../../../../modules/home/zellij.nix
    ./../../../../modules/home/btop.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    stateVersion = "24.11";
    username = "ritiek";
    homeDirectory = "/home/ritiek";
    # file.home-nix = {
    #   source = ./.;
    #   target = "${config.home.homeDirectory}/.config/home-manager";
    # };
    packages = with pkgs; [
      any-nix-shell
      psmisc
      lshw
      pciutils
      wget
      pv

      unzip
      unrar-wrapper
      sd
      # diskonaut
      compsize
      iotop
      python313Packages.ipython
      parted

      python313
      docker-compose
      compose2nix

      iptables
      nmap
      dig
      cryptsetup
      btrfs-progs
      openssl
      sops
      gnupg
      deploy-rs
      ssh-to-age
      age-plugin-fido2-hmac

      miniserve
      bore-cli
      immich-cli
      restic
      discordchatexporter-cli
      slackdump
      sqlcipher
      httrack
      yt-dlp
      mosquitto

      libgpiod
      i2c-tools
      # claude-code

      homelab-mount

      (writeShellScriptBin "homelab-unmount" ''
        set -x

        umount -l ${homelabMediaPath}
        umount -l ${everythingElsePath}

        cryptsetup close HOMELAB_MEDIA
        cryptsetup close EVERYTHING_ELSE
      '')

      (writeShellScriptBin "homelab-start" ''
        set -x
        homelab-mount && (
          systemctl start autostart-vaultwarden.service
          # systemctl start docker-dashy.service
          systemctl start autostart-homepage.service
          systemctl start docker-pihole.service
          systemctl start docker-uptime-kuma.service
          systemctl start docker-immich.service
          # systemctl start docker-tubearchivist.service
          systemctl start autostart-tubearchivist.service
          systemctl start docker-paperless-ngx-webserver.service
          # systemctl start docker-filebrowser-quantum.service
          systemctl start autostart-copyparty.service
          systemctl start docker-forgejo.service
          # systemctl start docker-navidrome.service
          systemctl start autostart-navidrome.service
          systemctl start autostart-memos.service
          systemctl start docker-syncthing.service
          systemctl start docker-miniflux.service
          systemctl start docker-gotify.service
          # systemctl start docker-shiori.service
          systemctl start autostart-homebox.service
          # systemctl start docker-conduwuit.service
          systemctl start autostart-grocy.service
          systemctl start docker-changedetection.service
          systemctl start docker-frigate.service
          systemctl start autostart-habitica-server.service
          # systemctl start docker-ollama.service
          systemctl start autostart-open-webui.service
          systemctl start autostart-pwpush.service
          systemctl start docker-dawarich.service docker-dawarich_sidekiq.service
          # systemctl start docker-rustdesk-hbbs.service
          # systemctl start docker-simplexchat-xftp-server.service docker-simplexchat-smp-server.service
          systemctl start autostart-nitter.service
          systemctl start autostart-mealie.service
          systemctl start autostart-karakeep.service
          systemctl start docker-n8n-worker.service
          # systemctl start docker-transmission.service
          systemctl start docker-qbittorrent.service
          systemctl start docker-jellyfin.service
          systemctl start docker-radarr.service
          systemctl start docker-sonarr.service
          systemctl start docker-bazarr.service
          systemctl start docker-prowlarr.service
          systemctl start docker-jellyseerr.service
          # systemctl start docker-kopia.service

          # machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start spotdl-sync.timer
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start paperless-ngx-sync.timer
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start whatsapp-backup-verify-latest-snapshot.timer
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start dns-resolution.timer
          # systemctl start spotdl-sync.timer

          # tailscale serve --bg --https=9445 127.0.0.1:9446
        )
      '')

      (writeShellScriptBin "homelab-stop" ''
        set -x
        systemctl stop autostart-vaultwarden.service docker-compose-vaultwarden-root.target
        # systemctl stop docker-compose-dashy-root.target
        systemctl stop autostart-homepage.service docker-compose-homepage-root.target
        systemctl stop docker-compose-pihole-root.target
        systemctl stop docker-compose-uptime-kuma-root.target
        systemctl stop docker-compose-immich-root.target
        systemctl stop autostart-tubearchivist.service docker-compose-tubearchivist-root.target
        systemctl stop docker-compose-paperless-ngx-root.target
        # systemctl stop docker-compose-filebrowser-quantum-root.target
        systemctl stop autostart-copyparty.service docker-compose-copyparty-root.target
        systemctl stop docker-compose-forgejo-root.target
        systemctl stop autostart-navidrome.service docker-compose-navidrome-root.target
        systemctl stop autostart-memos.service docker-compose-memos-root.target
        systemctl stop docker-compose-syncthing-root.target
        systemctl stop docker-compose-miniflux-root.target
        systemctl stop docker-compose-gotify-root.target
        # systemctl stop docker-compose-shiori-root.target
        systemctl stop autostart-homebox.service docker-compose-homebox-root.target
        systemctl stop docker-compose-conduwuit-root.target
        systemctl stop autostart-grocy.service docker-compose-grocy-root.target
        systemctl stop docker-compose-changedetection-root.target
        systemctl stop docker-compose-frigate-root.target
        systemctl stop autostart-habitica-server.service docker-compose-habitica-root.target
        systemctl stop autostart-open-webui.service docker-compose-ollama-webui-root.target
        systemctl stop autostart-pwpush.service docker-compose-pwpush-root.target
        systemctl stop docker-compose-dawarich-root.target
        systemctl stop docker-compose-rustdesk-root.target
        systemctl stop docker-compose-simplexchat-xftp-server-root.target docker-compose-simplexchat-smp-server-root.target
        systemctl stop autostart-nitter.service docker-compose-nitter-root.target
        systemctl stop autostart-mealie.service docker-compose-mealie-root.target
        systemctl stop autostart-karakeep.service docker-compose-karakeep-root.target
        systemctl stop docker-compose-n8n-root.target
        # systemctl stop docker-compose-transmission-root.target
        systemctl stop docker-compose-qbittorrent-root.target
        systemctl stop docker-compose-jellyfin-root.target
        systemctl stop docker-compose-radarr-root.target
        systemctl stop docker-compose-sonarr-root.target
        systemctl stop docker-compose-bazarr-root.target
        systemctl stop docker-compose-prowlarr-root.target
        systemctl stop docker-compose-jellyseerr-root.target
        # systemctl stop docker-compose-kopia-root.target

        # machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop spotdl-sync.timer
        # machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop spotdl-sync.service
        machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop paperless-ngx-sync.timer
        machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop paperless-ngx-sync.service
        machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop whatsapp-backup-verify-latest-snapshot.timer
        machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop whatsapp-backup-verify-latest-snapshot.service
        machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop dns-resolution.timer
        machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop dns-resolution.service
        # systemctl stop spotdl-sync.timer

        # tailscale serve --https=9445 off
      '')

    ];
  };
  programs = {
    command-not-found.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
    claude-code.enable = true;
  };
}
