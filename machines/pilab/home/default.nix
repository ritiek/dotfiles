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
      # ./../../../home/gnupg.nix
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

        homelab-mount

        (writeShellScriptBin "homelab-unmount" ''
          set -x
          umount -l /media
          ${pkgs.cryptsetup}/bin/cryptsetup close homelab_media
        '')

        (writeShellScriptBin "homelab-stop" ''
          set -x
          ${pkgs.systemd}/bin/systemctl stop docker-compose-dashy-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-pihole-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-uptime-kuma-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-immich-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-tubearchivist-root.target
          ${pkgs.systemd}/bin/systemctl stop docker-compose-paperless-ngx-root.target

          ${pkgs.tailscale}/bin/tailscale serve --https=9445 off
        '')

        (writeShellScriptBin "homelab-start" ''
          set -x
          ${homelab-mount}/bin/homelab-mount && (
            # Disable serve for Vaultwarden can bind to port 9445
            ${pkgs.tailscale}/bin/tailscale serve --https=9445 off

            ${pkgs.systemd}/bin/systemctl start docker-dashy.service
            ${pkgs.systemd}/bin/systemctl start docker-pihole.service
            ${pkgs.systemd}/bin/systemctl start docker-uptime-kuma.service
            ${pkgs.systemd}/bin/systemctl start docker-immich_server.service
            ${pkgs.systemd}/bin/systemctl start docker-tubearchivist.service
            ${pkgs.systemd}/bin/systemctl start docker-paperless-ngx-webserver.service

            # Disable serve for Matrix Dendrite can bind to port 8008
            # {pkgs.tailscale}/bin/tailscale serve --https=8008 off
            ${pkgs.tailscale}/bin/tailscale serve --bg --https=9445 127.0.0.1:9445
            # {pkgs.tailscale}/bin/tailscale serve --bg --https=8008 127.0.0.1:8008
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
