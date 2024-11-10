{ pkgs, inputs, config, ... }:
let 
  homelab-mount = (pkgs.writeShellScriptBin "homelab-mount" ''
    set -x
    ${pkgs.cryptsetup}/bin/cryptsetup open \
      /dev/disk/by-label/HOMELAB_MEDIA \
      homelab_media
    mount -o defaults,noatime,nodiscard,noautodefrag,ssd,space_cache=v2,compress-force=zstd:3 \
      /dev/mapper/homelab_media \
      /media
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
      ./../../../modules/home/sops.nix
      ./../../../modules/home/nix.nix
      # ./../../../modules/home/gnupg.nix
      ./../../../modules/home/zsh
      ./../../../modules/home/git
      ./../../../modules/home/neovim
      ./../../../modules/home/zellij.nix
      ./../../../modules/home/btop.nix
    ];
    # sops.secrets."immich_cli_env" = {};
    # sops.secrets."immich_cli_env".path = "${config.home.homeDirectory}/secret";

    sops.secrets."paperless_ngx_cli_env" = {};
    # sops.secrets."paperless_ngx_cli_env".path = "${config.home.homeDirectory}/.config/nix/nix.conf";

    # systemd.user.services.sops-nix.enable = true;
    # systemd.user.services.sops-nix.Install.WantedBy = [ "graphical-session-pre.target" ];
    home = {
      stateVersion = "24.11";
      packages = with pkgs; [
        any-nix-shell

        unzip
        unrar-wrapper
        sd
        diskonaut
        compsize

        podman-compose
        compose2nix

        iptables
        nmap
        dig
        cryptsetup
        openssl
        sops
        gnupg
        deploy-rs

        miniserve
        bore-cli
        immich-cli

        homelab-mount

        # (writeShellScriptBin "testes" ''
        #   ${pkgs.coreutils}/bin/echo "${config.sops.gnupg.home}"
        # '')

        (writeShellScriptBin "homelab-unmount" ''
          set -x
          umount -l /media
          ${pkgs.cryptsetup}/bin/cryptsetup close homelab_media
        '')

        (writeShellScriptBin "homelab-stop" ''
          set -x
          ${pkgs.systemd}/bin/systemctl stop docker-compose-vaultwarden-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-dashy-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-pihole-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-uptime-kuma-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-immich-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-tubearchivist-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-paperless-ngx-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-forgejo-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-navidrome-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-memos-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-syncthing-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-miniflux-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-gotify-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-shiori-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-homebox-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-conduwuit-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-grocy-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-kopia-root.target
          ${pkgs.systemd}/bin/systemctl stop spotdl-sync.timer

          ${pkgs.tailscale}/bin/tailscale serve --https=9445 off
        '')

        (writeShellScriptBin "homelab-start" ''
          set -x
          ${homelab-mount}/bin/homelab-mount && (
            ${pkgs.systemd}/bin/systemctl start docker-vaultwarden.service
            ${pkgs.systemd}/bin/systemctl start docker-dashy.service
            ${pkgs.systemd}/bin/systemctl start docker-pihole.service
            ${pkgs.systemd}/bin/systemctl start docker-uptime-kuma.service
            ${pkgs.systemd}/bin/systemctl start docker-immich.service
            ${pkgs.systemd}/bin/systemctl start docker-tubearchivist.service
            ${pkgs.systemd}/bin/systemctl start docker-paperless-ngx-webserver.service
            ${pkgs.systemd}/bin/systemctl start docker-forgejo.service
            ${pkgs.systemd}/bin/systemctl start docker-navidrome.service
            ${pkgs.systemd}/bin/systemctl start docker-memos.service
            ${pkgs.systemd}/bin/systemctl start docker-syncthing.service
            ${pkgs.systemd}/bin/systemctl start docker-miniflux.service
            ${pkgs.systemd}/bin/systemctl start docker-gotify.service
            ${pkgs.systemd}/bin/systemctl start docker-shiori.service
            ${pkgs.systemd}/bin/systemctl start docker-homebox.service
            ${pkgs.systemd}/bin/systemctl start docker-conduwuit.service
            ${pkgs.systemd}/bin/systemctl start docker-grocy.service
            ${pkgs.systemd}/bin/systemctl start docker-kopia.service
            ${pkgs.systemd}/bin/systemctl start spotdl-sync.timer

            ${pkgs.tailscale}/bin/tailscale serve --bg --https=9445 127.0.0.1:9446
          )
        '')

        # (writeShellScriptBin "immich-with-env" ''
        #   source ${config.sops.secrets."immich_cli_env".path}
        #   ${pkgs.immich-cli}/bin/immich "$@"
        # '')

        # (writeShellScriptBin "immich-with-env" ''
        #   ${pkgs.immich-cli}/bin/immich "$@"
        # '')

        # source ${config.sops.secrets."paperless_ngx_cli_env".path}

        (writeShellScriptBin "push-to-paperless-ngx" ''
          # Check if at least one file argument is provided
          if [ $# -lt 1 ]; then
              echo "Usage: $0 <file_to_upload> [<file_to_upload> ...]"
              exit 1
          fi
          
          # TODO: Shouldn't have to hardcode the path here.
          source ~/.config/sops-nix/secrets/paperless_ngx_cli_env
          
          # Loop through all provided files
          for FILE in "$@"; do
              # Check if the file exists and is a regular file
              if [ ! -f "$FILE" ]; then
                  echo "Error: $FILE does not exist or is not a valid file."
                  continue
              fi
          
              # Upload the file
              echo "Uploading $FILE..."
          
              curl -H "Authorization: Token $PAPERLESS_NGX_API_KEY" -F "document=@$FILE" "$PAPERLESS_NGX_INSTANCE_PUSH_DOCUMENT_URL"
          
              if [ $? -eq 0 ]; then
                  echo "$FILE uploaded successfully."
              else
                  echo "Failed to upload $FILE."
              fi
          done
          
          echo "File upload process complete."
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
