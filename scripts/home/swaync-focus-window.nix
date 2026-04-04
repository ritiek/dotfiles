{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (writeShellScriptBin "swaync-focus-window" ''
      if [ "$SWAYNC_APP_NAME" = "opencode" ]; then
        win_id=$(niri msg --json windows | jq -r --arg body "$SWAYNC_BODY" '
          first(
            .[] | select(.title | startswith("OC | "))
            | .id as $id
            | .title
            | sub("^OC \\| "; "")
            | sub("[.]{3}$"; "")
            | select(. as $t | $body | contains($t))
            | $id
          ) // empty
        ')
        if [ -n "$win_id" ]; then
          niri msg action focus-window --id "$win_id"
        fi
      else
        niri msg --json windows | jq -r --arg app "$SWAYNC_APP_NAME" '
          first(.[] | select(.app_id == $app) | .id // empty)
        ' | xargs -r -I{} niri msg action focus-window --id {}
      fi
    '')
  ];
}
