{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (writeShellScriptBin "swaync-focus-window" ''
      if [ "$SWAYNC_APP_NAME" = "opencode" ]; then
        session_title="''${SWAYNC_BODY#*: }"
        niri msg --json windows | jq -r --arg title "$session_title" '
          first(.[] | select(.title | startswith("OC | ")) | select(.title | contains($title)) | .id // empty)
        ' | xargs -r -I{} niri msg action focus-window --id {}
      else
        niri msg --json windows | jq -r --arg app "$SWAYNC_APP_NAME" '
          first(.[] | select(.app_id == $app) | .id // empty)
        ' | xargs -r -I{} niri msg action focus-window --id {}
      fi
    '')
  ];
}
