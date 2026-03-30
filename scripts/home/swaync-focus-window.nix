{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (writeShellScriptBin "swaync-focus-window" ''
      niri msg --json windows | jq -r --arg app "$SWAYNC_APP_NAME" '
        first(.[] | select(.app_id == $app) | .id // empty)
      ' | xargs -r -I{} niri msg action focus-window --id {}
    '')
  ];
}
