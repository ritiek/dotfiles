{ pkgs, inputs, config, ... }:
let 
  homelab-mount = (pkgs.writeShellScriptBin "homelab-mount" ''
    set -x
    cryptsetup open \
      /dev/disk/by-label/HOMELAB_MEDIA \
      HOMELAB_MEDIA
    mount -o defaults,noatime,nodiscard,noautodefrag,ssd,space_cache=v2,compress-force=zstd:3 \
      /dev/mapper/HOMELAB_MEDIA \
      /media/HOMELAB_MEDIA
  '');
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };
  };

  environment.pathsToLink = [
    "/share/zsh"
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  home-manager.users.root = {
    imports = [
      ./../../../modules/home/zsh
      ./../../../modules/home/neovim
    ];
    home.stateVersion = "24.11";
  };

  systemd.tmpfiles.settings."10-ssh"."/home/ritiek/.ssh/sops.id_ed25519" = {
    "C+" = {
      mode = "0600";
      user = "ritiek";
      argument = "/etc/ssh/ssh_host_ed25519_key";
    };
  };
  home-manager.users.ritiek = { osConfig, config, ... }: {
    imports = [
      ./services/spotdl.nix
      ./services/paperless-ngx.nix
      ./services/whatsapp-backup-verify.nix
      ./../../../scripts/home/immich-env.nix
      ./../../../modules/home/sops.nix
      ./../../../modules/home/nix.nix
      # ./../../../modules/home/gnupg.nix
      ./../../../modules/home/zsh
      ./../../../modules/home/git
      ./../../../modules/home/neovim
      ./../../../modules/home/zellij.nix
      ./../../../modules/home/btop.nix
    ];
    home = {
      stateVersion = "24.11";
      packages = with pkgs; [
        any-nix-shell

        unzip
        unrar-wrapper
        sd
        # diskonaut
        compsize

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

        miniserve
        bore-cli
        immich-cli
        restic
        discordchatexporter-cli

        homelab-mount

        (writeShellScriptBin "homelab-unmount" ''
          set -x
          umount -l /media/HOMELAB_MEDIA
          cryptsetup close homelab_media
        '')

        (writeShellScriptBin "homelab-stop" ''
          set -x
          systemctl stop docker-compose-vaultwarden-root.target
          # systemctl stop docker-compose-dashy-root.target
          systemctl stop docker-compose-homepage-root.target
          systemctl stop docker-compose-pihole-root.target
          systemctl stop docker-compose-uptime-kuma-root.target
          systemctl stop docker-compose-immich-root.target
          systemctl stop docker-compose-tubearchivist-root.target
          systemctl stop docker-compose-paperless-ngx-root.target
          systemctl stop docker-compose-forgejo-root.target
          systemctl stop docker-compose-navidrome-root.target
          systemctl stop docker-compose-memos-root.target
          systemctl stop docker-compose-syncthing-root.target
          systemctl stop docker-compose-miniflux-root.target
          systemctl stop docker-compose-gotify-root.target
          systemctl stop docker-compose-shiori-root.target
          systemctl stop docker-compose-homebox-root.target
          systemctl stop docker-compose-conduwuit-root.target
          systemctl stop docker-compose-grocy-root.target
          systemctl stop docker-compose-changedetection-root.target
          systemctl stop docker-compose-frigate-root.target
          systemctl stop docker-compose-habitica-root.target
          systemctl stop docker-compose-ollama-webui-root.target
          systemctl stop docker-compose-pwpush-root.target
          # systemctl stop docker-compose-kopia-root.target
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop spotdl-sync.service
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop spotdl-sync.timer
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop paperless-ngx-sync.service
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop paperless-ngx-sync.timer
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop whatsapp-backup-verify-latest-snaphost.service
          machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user stop whatsapp-backup-verify-latest-snaphost.timer
          # systemctl stop spotdl-sync.timer

          tailscale serve --https=9445 off
        '')

        (writeShellScriptBin "homelab-start" ''
          set -x
          homelab-mount && (
            systemctl start docker-vaultwarden.service
            # systemctl start docker-dashy.service
            systemctl start docker-homepage.service
            systemctl start docker-pihole.service
            systemctl start docker-uptime-kuma.service
            systemctl start docker-immich.service
            systemctl start docker-tubearchivist.service
            systemctl start docker-paperless-ngx-webserver.service
            systemctl start docker-forgejo.service
            systemctl start docker-navidrome.service
            systemctl start docker-memos.service
            systemctl start docker-syncthing.service
            systemctl start docker-miniflux.service
            systemctl start docker-gotify.service
            systemctl start docker-shiori.service
            systemctl start docker-homebox.service
            systemctl start docker-conduwuit.service
            systemctl start docker-grocy.service
            systemctl start docker-changedetection.service
            systemctl start docker-frigate.service
            systemctl start docker-habitica-server.service
            systemctl start docker-open-webui.service
            systemctl start docker-pwpush.service
            # systemctl start docker-kopia.service
            machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start spotdl-sync.timer
            machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start paperless-ngx-sync.timer
            machinectl shell ${config.home.username}@ ${pkgs.systemd}/bin/systemctl --user start whatsapp-backup-verify-latest-snaphost.timer
            # systemctl start spotdl-sync.timer

            tailscale serve --bg --https=9445 127.0.0.1:9446
          )
        '')

      ];
    };
    programs = {
      command-not-found.enable = true;
      home-manager.enable = true;
      jq.enable = true;
      ripgrep.enable = true;
      fd.enable = true;
    };
  };
}
