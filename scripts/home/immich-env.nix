{ pkgs, inputs, config, ... }:
{
  sops.secrets."immich-cli.env" = {};

  home.packages = with pkgs; [
    (writeShellScriptBin "immich@env" ''
      # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
      # to work:
      # eval $(${pkgs.coreutils}/bin/cat $\{config.sops.secrets."immich-cli.env".path}) ${pkgs.immich-cli}/bin/immich "$@"
      eval $(${pkgs.coreutils}/bin/cat ~/.config/sops-nix/secrets/immich-cli.env) ${pkgs.immich-cli}/bin/immich "$@"
    '')
  ];
}
