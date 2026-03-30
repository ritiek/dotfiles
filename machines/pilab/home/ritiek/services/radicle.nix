{ config, pkgs, ... }:
let
  radicleKeysDir = "${config.home.homeDirectory}/.radicle/keys";
in
{
  programs.radicle = {
    enable = true;
    settings.node = {
      alias = "clawsiecats";
      listen = [ "0.0.0.0:8776" ];
    };
  };
  services.radicle.node.enable = true;

  sops.secrets."radicle.clawsiecats" = {};

  home.file.".radicle/config.json".force = true;
  home.file."${radicleKeysDir}/radicle.pub" = {
    text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDzRPabJk92QRvD4nVdL2TPcxFzgHy3TAUwC0W8t5hMs";
    force = true;
  };

  systemd.user.services.radicle-setup-keys = {
    Unit = {
      Description = "Copy Radicle private key from sops secret";
      Requires = [ "sops-nix.service" ];
      After = [ "sops-nix.service" ];
      Before = [ "radicle-node.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "radicle-setup-keys" ''
        set -eu
        ${pkgs.coreutils}/bin/mkdir -p ${radicleKeysDir}
        ${pkgs.coreutils}/bin/cp -f \
          ${config.sops.secrets."radicle.clawsiecats".path} \
          ${radicleKeysDir}/radicle
        ${pkgs.coreutils}/bin/chmod 0600 ${radicleKeysDir}/radicle
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.radicle-node = {
    Unit = {
      After = [ "radicle-setup-keys.service" ];
      Wants = [ "radicle-setup-keys.service" ];
    };
  };
}
