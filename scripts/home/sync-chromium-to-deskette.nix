{ pkgs, ... }:
let
  desketteHost = "deskette.lion-zebra.ts.net";
  remoteUser = "ritiek";
  profileRel = ".config/chromium/Default";
in
{
  # Manually-triggered one-way sync of this machine's (mishy's) interactive
  # Chromium profile onto deskette's persistent shared Chromium (see
  # modules/home/niri chromium-cdp-launcher + modules/home/opencode.nix
  # chromium-cdp-forward). deskette's browser is the single instance that
  # mishy's OpenCode Playwright MCP attaches to over CDP, so this is how
  # deskette picks up mishy's cookies/logins/session state.
  #
  # One-way, mishy -> deskette: deskette's copy of Default/ is always overwritten.
  # Excludes cache-only directories (Service Worker, GPUCache, etc.) which are
  # by far the bulk of the profile but carry no login state, and excludes the
  # Singleton* IPC lock files which are host/process-specific.
  #
  # Chromium must be stopped on deskette before overwriting live SQLite dbs
  # (Cookies, Login Data) to avoid corrupting them mid-write. deskette's
  # chromium-cdp-launcher wraps Chromium in a `while true; do chromium ...; done`
  # restart loop, so killing just the chromium process (not the wrapper) makes
  # it auto-relaunch a couple of seconds later with the freshly-synced profile.
  home.packages = with pkgs; [
    (writeShellScriptBin "sync-chromium-to-deskette" ''
      set -euo pipefail

      SSH_BIN="${pkgs.openssh}/bin/ssh"
      HOST="${desketteHost}"
      USER="${remoteUser}"
      SRC="$HOME/${profileRel}/"
      DEST="$USER@$HOST:${profileRel}/"

      # Resolve to a literal IP: Chrome's DevTools HTTP server rejects any
      # Host header that isn't a literal IP or "localhost" (anti DNS-rebinding
      # protection), and the socat forward on deskette (chromium-cdp-forward)
      # doesn't rewrite Host headers.
      CDP_IP=$(${pkgs.getent}/bin/getent hosts "$HOST" | ${pkgs.gawk}/bin/awk '{print $1; exit}')

      if ${pkgs.procps}/bin/pgrep -f "user-data-dir=$HOME/.config/chromium" >/dev/null 2>&1; then
        echo "warning: chromium is currently running locally; the copy may miss its most recent writes." >&2
      fi

      echo "==> Stopping Chromium on deskette (its supervisor loop will relaunch it after sync)..."
      "$SSH_BIN" "$USER@$HOST" '
        pkill -f "user-data-dir=$HOME/.config/chromium" || true
        for i in $(seq 1 20); do
          pgrep -f "user-data-dir=$HOME/.config/chromium" >/dev/null 2>&1 || break
          sleep 0.5
        done
        pkill -9 -f "user-data-dir=$HOME/.config/chromium" 2>/dev/null || true
        rm -f "$HOME/.config/chromium/SingletonLock" "$HOME/.config/chromium/SingletonSocket" "$HOME/.config/chromium/SingletonCookie"
      '

      echo "==> Syncing $SRC -> deskette:${profileRel}/ ..."
      "${pkgs.rsync}/bin/rsync" -az --delete \
        --exclude='Service Worker/' \
        --exclude='Code Cache/' \
        --exclude='GPUCache/' \
        --exclude='Shared Dictionary/' \
        --exclude='File System/' \
        --exclude='DawnWebGPUCache/' \
        --exclude='DawnGraphiteCache/' \
        --exclude='Crash Reports/' \
        --exclude='SingletonLock' \
        --exclude='SingletonSocket' \
        --exclude='SingletonCookie' \
        -e "$SSH_BIN" \
        "$SRC" "$DEST"

      echo "==> Waiting for deskette's Chromium CDP to come back up on $CDP_IP:9222 ..."
      for i in $(seq 1 20); do
        if "${pkgs.curl}/bin/curl" -sf "http://$CDP_IP:9222/json/version" >/dev/null 2>&1; then
          echo "==> Done. deskette's Chromium is back up with the synced profile."
          exit 0
        fi
        sleep 1
      done

      echo "error: deskette's Chromium did not come back up within 20s." >&2
      exit 1
    '')
  ];
}
