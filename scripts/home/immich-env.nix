{ pkgs, inputs, config, ... }:
{
  sops.secrets."immich-cli.env" = {};

  home.packages = with pkgs; [
    (writeShellScriptBin "immich@env" ''
      eval $(${pkgs.coreutils}/bin/cat "${config.sops.secrets."immich-cli.env".path}") ${pkgs.immich-cli}/bin/immich "$@"
    '')
  ];
}
