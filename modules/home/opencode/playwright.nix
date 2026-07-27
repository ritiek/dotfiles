{ pkgs, inputs, lib, hostName, ... }:
let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # On pilab (aarch64), pkgs.chromium has no binary cache for the pinned nixpkgs
  # and would build from source (~100GB scratch), exhausting the disk. The unstable
  # nixpkgs DOES have a cached aarch64 build, so use it there. Other hosts keep
  # pkgs.chromium unchanged.
  chromiumPackage = if hostName == "pilab" then pkgs.unstable.chromium else pkgs.chromium;

  # Bounded connect/liveness timeouts so a dead network or unresponsive deskette
  # fails within ~15s instead of hanging forever, plus a per-invocation
  # multiplexed control connection (keyed by this script's own PID, like
  # REMOTE_TEMP_PROFILE) so the setup and cleanup round trips reuse one SSH
  # handshake instead of paying for it twice.
  sshOpts = "-o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 -o ControlMaster=auto -o ControlPersist=30s -o ControlPath=/tmp/.ssh-cdp-ctrl-$$";

  # deskette: connects to its own loopback CDP (persistent Chromium via
  # chromium-cdp-launcher in modules/home/niri). Host in the discovery
  # response matches exactly (127.0.0.1), so no path-rewriting is needed.
  playwright-mcp-local-cdp-wrapper = pkgs.writeShellScript "playwright-mcp-local-cdp-wrapper" ''
    # See playwright-mcp-agent-wrapper for why: an inherited HTTP(S)_PROXY can
    # intercept/break CDP traffic even to loopback addresses, and playwright-mcp
    # (Node/undici) does not honor NO_PROXY to work around it.
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    exec ${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp \
      --cdp-endpoint http://127.0.0.1:9222 \
      --caps vision \
      "$@"
  '';

  # Per-agent isolated Chromium on deskette via SSH. Each agent invocation:
  # 1. Copies the main Chromium profile to a unique temp dir on deskette and
  #    launches a headed Chromium there with a unique CDP port + dedicated
  #    socat forwarder, in one SSH round trip (retried once on failure).
  # 2. Waits for CDP to come up, failing fast if it never does.
  # 3. Connects playwright-mcp to that instance over Tailscale.
  # 4. On exit, kills the remote Chrome and removes the temp profile.
  #
  # Orphaned profiles from crashed/killed invocations are not swept here — a
  # standalone systemd timer on deskette (chromium-agent-sweep) does that
  # independently every few minutes, so cleanup isn't tied to another agent
  # happening to launch.
  #
  # This gives each agent its own isolated browser with deskette's GPU
  # acceleration, avoiding conflicts between parallel agents.
  playwright-mcp-agent-wrapper = pkgs.writeShellScript "playwright-mcp-agent-wrapper" ''
    set -euo pipefail

    # An HTTP(S)_PROXY inherited from OpenCode's own environment (used to proxy
    # LLM API calls through pilab.lion-zebra.ts.net:8090) must not leak into
    # this subprocess's remote/CDP traffic, which the proxy intercepts and
    # rejects with 407. Unsetting here only affects this subprocess and its
    # children (ssh, curl, playwright-mcp) at every step below, including the
    # CDP readiness check — OpenCode's own parent process and its LLM requests
    # are unaffected, since environment changes never propagate to a parent.
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

    SSH_BIN="${pkgs.openssh}/bin/ssh"
    HOST="deskette.lion-zebra.ts.net"
    USER="ritiek"
    AGENT_PORT=$(( 20000 + RANDOM % 30000 ))
    REMOTE_TEMP_PROFILE="/tmp/chromium-agent-$$"
    LOG="$HOME/.cache/playwright-agent-wrapper.log"
    mkdir -p "$HOME/.cache"
    log() { echo "$(${pkgs.coreutils}/bin/date -Iseconds) [port=$AGENT_PORT] $1" >> "$LOG" 2>/dev/null || true; }
    remote() { "$SSH_BIN" -n ${sshOpts} "$USER@$HOST" "$@"; }

    # Resolve deskette to literal Tailscale IP: Chrome's DevTools HTTP server
    # rejects any Host header that isn't a literal IP or "localhost".
    CDP_IP=$(${pkgs.getent}/bin/getent hosts "$HOST" | ${pkgs.gawk}/bin/awk '{print $1; exit}')

    echo "==> Setting up isolated Chromium for agent on deskette (port $AGENT_PORT)..." >&2

    # Copy profile + launch Chromium/socat in one round trip. Chromium's
    # DevTools server always binds 127.0.0.1 regardless of
    # --remote-debugging-address, so a per-agent socat forwarder exposes it on
    # deskette's Tailscale IP (mirrors chromium-cdp-forward for the persistent
    # instance's fixed port 9222). Remote `set -e` ensures a failed copy
    # aborts before ever attempting to launch Chromium.
    copy_and_launch() {
      remote "
        set -e
        rm -rf '$REMOTE_TEMP_PROFILE'
        cp -a ~/.config/chromium '$REMOTE_TEMP_PROFILE'
        rm -f '$REMOTE_TEMP_PROFILE/SingletonLock' \
              '$REMOTE_TEMP_PROFILE/SingletonSocket' \
              '$REMOTE_TEMP_PROFILE/SingletonCookie'
        export LIBVA_DRIVER_NAME=i965
        nohup ${chromiumPackage}/bin/chromium \
          --ozone-platform=wayland \
          --remote-debugging-port=$AGENT_PORT \
          --remote-allow-origins='*' \
          --user-data-dir='$REMOTE_TEMP_PROFILE' \
          --no-first-run \
          --password-store=basic \
          </dev/null >/dev/null 2>&1 &
        echo \$! > '$REMOTE_TEMP_PROFILE/.pid'
        nohup ${pkgs.socat}/bin/socat TCP-LISTEN:$AGENT_PORT,bind='$CDP_IP',fork,reuseaddr TCP:127.0.0.1:$AGENT_PORT \
          </dev/null >/dev/null 2>&1 &
        echo \$! > '$REMOTE_TEMP_PROFILE/.socat.pid'
      "
    }

    ok=false
    for attempt in 1 2; do
      if copy_and_launch; then ok=true; break; fi
      echo "==> Setup attempt $attempt failed, retrying..." >&2
      sleep 2
    done
    if [ "$ok" != true ]; then
      log "FAILED: profile copy / Chromium launch failed after 2 attempts"
      echo "ERROR: failed to set up Chromium on deskette after 2 attempts" >&2
      exit 1
    fi

    # Wait for CDP to actually come up; fail fast rather than launching
    # playwright-mcp against a dead endpoint, which would otherwise surface as
    # a confusing downstream connection error instead of a clear setup failure.
    cdp_up=false
    for i in $(seq 1 20); do
      if ${pkgs.curl}/bin/curl -sf "http://$CDP_IP:$AGENT_PORT/json/version" >/dev/null 2>&1; then
        cdp_up=true
        break
      fi
      sleep 1
    done
    if [ "$cdp_up" != true ]; then
      log "FAILED: CDP did not come up on port $AGENT_PORT within 20s"
      echo "ERROR: Chromium CDP did not come up on deskette within 20s" >&2
      exit 1
    fi

    # NOTE: deliberately not `exec`'d — exec would replace this process (and
    # its trap handlers) with playwright-mcp, so a SIGTERM from the parent
    # (e.g. OpenCode killing the MCP server) would skip cleanup() below and
    # orphan the remote Chrome + temp profile on deskette forever.
    #
    # The trailing `<&0` is required: bash gives a backgrounded (`&`) command
    # /dev/null as stdin unless it explicitly redirects its own stdin, and
    # playwright-mcp is an MCP stdio server reading OpenCode's requests from
    # this process's stdin — without `<&0` it sees immediate EOF and exits
    # within milliseconds of launching.
    ${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp \
      --cdp-endpoint "http://$CDP_IP:$AGENT_PORT" \
      --caps vision \
      "$@" <&0 &
    PLAYWRIGHT_PID=$!

    # Cleanup matches on the (unique per-agent) profile path rather than just
    # the top-level PID from .pid: a plain `kill` doesn't cascade to
    # Chromium's renderer/GPU/utility children, so they'd orphan and keep the
    # profile's files open, making rm -rf race or fail.
    #
    # The remote script assigns the path to a remote-side $DIR first and
    # references it via escaped \$DIR everywhere after, rather than
    # re-embedding the expanded local path in every pkill/pgrep pattern. This
    # avoids a `pkill -f` self-match footgun: if the fully-expanded path were
    # embedded directly in the pkill pattern text, that same text would also
    # appear verbatim in this remote shell's OWN argv (it's literally part of
    # the -c string being run) — and `pkill -f` matches against ALL
    # processes' cmdlines, including its own parent, killing the cleanup
    # script itself before it ever reaches rm -rf.
    cleanup() {
      kill "$PLAYWRIGHT_PID" 2>/dev/null || true
      remote "
        DIR='$REMOTE_TEMP_PROFILE'
        [ -f \"\$DIR/.socat.pid\" ] && kill -9 \$(cat \"\$DIR/.socat.pid\") 2>/dev/null
        pkill -9 -f \"user-data-dir=\$DIR\" 2>/dev/null || true
        for i in \$(seq 1 10); do
          pgrep -f \"user-data-dir=\$DIR\" >/dev/null 2>&1 || break
          sleep 0.3
        done
        rm -rf \"\$DIR\"
      " || log "cleanup ssh call failed for $REMOTE_TEMP_PROFILE"
    }
    trap cleanup EXIT INT TERM SIGINT SIGTERM

    wait "$PLAYWRIGHT_PID"
  '';

  # Standalone sweep of orphaned /tmp/chromium-agent-* dirs on deskette,
  # independent of any agent invocation — the real safety net if OpenCode
  # itself is killed before playwright-mcp-agent-wrapper's own EXIT trap can
  # run. Runs directly on deskette via bash (not over SSH), so no zsh-glob
  # quoting concerns apply here. Skips dirs younger than 30s (a sibling agent
  # may still be mid profile-copy) and any dir a live Chromium is still using.
  chromium-agent-sweep-script = pkgs.writeShellScript "chromium-agent-sweep" ''
    for dir in /tmp/chromium-agent-*; do
      [ -d "$dir" ] || continue
      [ -n "$(find "$dir" -maxdepth 0 -mmin -0.5 2>/dev/null)" ] && continue
      pgrep -f "user-data-dir=$dir" >/dev/null 2>&1 && continue
      [ -f "$dir/.socat.pid" ] && kill -9 "$(cat "$dir/.socat.pid")" 2>/dev/null
      rm -rf "$dir"
    done
  '';
in
{
  inherit chromiumPackage;

  chromiumProgram = {
    enable = true;
    package = chromiumPackage;
  };

  # deskette connects to its own local persistent Chromium CDP.
  # All other machines: each agent gets its own isolated Chromium
  # instance on deskette with a unique temp profile and CDP port.
  mcpCommand = [
    (if hostName == "deskette"
     then "${playwright-mcp-local-cdp-wrapper}"
     else "${playwright-mcp-agent-wrapper}")
  ];

  systemdServices = lib.optionalAttrs (hostName == "deskette") {
    # Forwards deskette's Tailscale IP:9222 to the persistent Chromium CDP
    # listener on 127.0.0.1:9222 (Chrome only ever binds loopback for CDP).
    # Binds specifically to the tailscale interface address, not 0.0.0.0,
    # since networking.firewall is disabled on this machine and there is
    # no other layer restricting exposure.
    chromium-cdp-forward = {
      Unit = {
        Description = "Forward deskette Tailscale IP:9222 to local Chromium CDP port";
        After = [ "tailscaled.service" "network-online.target" ];
        Wants = [ "tailscaled.service" "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.socat}/bin/socat TCP-LISTEN:9222,bind=$(${pkgs.tailscale}/bin/tailscale ip -4),fork,reuseaddr TCP:127.0.0.1:9222'";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Independent periodic cleanup of orphaned per-agent Chromium profiles;
    # triggered by the chromium-agent-sweep.timer below.
    chromium-agent-sweep = {
      Unit.Description = "Sweep orphaned per-agent Chromium profiles on deskette";
      Service = {
        Type = "oneshot";
        ExecStart = "${chromium-agent-sweep-script}";
      };
    };
  };

  systemdTimers = lib.optionalAttrs (hostName == "deskette") {
    chromium-agent-sweep = {
      Unit.Description = "Run chromium-agent-sweep periodically";
      Timer = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
