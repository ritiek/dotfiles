{ pkgs, inputs, lib, hostName, ... }:
let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # On pilab (aarch64), pkgs.chromium has no binary cache for the pinned nixpkgs
  # and would build from source (~100GB scratch), exhausting the disk. The unstable
  # nixpkgs DOES have a cached aarch64 build, so use it there. Other hosts keep
  # pkgs.chromium unchanged.
  chromiumPackage = if hostName == "pilab" then pkgs.unstable.chromium else pkgs.chromium;

  # deskette: connects to its own loopback CDP (persistent Chromium via
  # chromium-cdp-launcher in modules/home/niri). Host in the discovery
  # response matches exactly (127.0.0.1), so no path-rewriting is needed.
  playwright-mcp-local-cdp-wrapper = pkgs.writeShellScript "playwright-mcp-local-cdp-wrapper" ''
    exec ${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp \
      --cdp-endpoint http://127.0.0.1:9222 \
      --caps vision \
      "$@"
  '';

  # Per-agent isolated Chromium on deskette via SSH. Each agent invocation:
  # 1. Sweeps /tmp/chromium-agent-* on deskette, removing any orphaned temp
  #    profiles left behind by a prior agent that didn't clean up (crash,
  #    SIGKILL, etc.) — mirrors the orphan-sweep pattern from the old local
  #    playwright-mcp-wrapper, adapted for remote/SSH execution.
  # 2. Copies the main Chromium profile to a unique temp dir on deskette
  # 3. Launches a headed Chromium instance with that temp profile + unique CDP port
  # 4. Connects playwright-mcp to that instance over Tailscale
  # 5. On exit, kills the remote Chrome and cleans up the temp profile
  #
  # This gives each agent its own isolated browser with deskette's GPU
  # acceleration, avoiding conflicts between parallel agents.
  #
  # Unsets proxy env vars because the proxy (pilab.lion-zebra.ts.net:8090)
  # intercepts Tailscale connections and returns 407. NO_PROXY alone is
  # insufficient — Playwright MCP (Node.js) does not respect it for CDP.
  playwright-mcp-agent-wrapper = pkgs.writeShellScript "playwright-mcp-agent-wrapper" ''
    set -euo pipefail

    SSH_BIN="${pkgs.openssh}/bin/ssh"
    HOST="deskette.lion-zebra.ts.net"
    USER="ritiek"
    AGENT_PORT=$((9222 + RANDOM % 5000))
    REMOTE_TEMP_PROFILE="/tmp/chromium-agent-$$"

    # Resolve deskette to literal Tailscale IP (Chrome rejects hostname Host headers)
    CDP_IP=$(${pkgs.getent}/bin/getent hosts "$HOST" | ${pkgs.gawk}/bin/awk '{print $1; exit}')

    echo "==> Setting up isolated Chromium for agent on deskette (port $AGENT_PORT)..." >&2

    # Sweep orphaned agent profiles left behind by prior crashed/killed
    # invocations: for each /tmp/chromium-agent-* dir, if no Chromium
    # process is currently using it (per-directory pgrep check), kill its
    # matching socat forwarder (if any, via the saved .socat.pid) and
    # remove the directory. Deliberately uses narrow per-directory pgrep
    # checks rather than a broad pkill -f across many PIDs at once — the
    # latter was empirically observed to hang intermittently over SSH
    # with zero output, even under `timeout`.
    #
    # Skips directories younger than 30s (find -mmin -0.5): without this,
    # two agents launched concurrently can race each other here — agent B
    # starts while agent A's `cp -a` profile copy is still in flight (or
    # just finished but chromium hasn't launched yet), so agent A's
    # directory has no matching `user-data-dir=` process YET and looks
    # "orphaned" to agent B's sweep, which then deletes it out from under
    # agent A. A grace period gives a sibling's copy+launch time to
    # complete before it's ever considered for cleanup. Empirically
    # confirmed via concurrent testing: without this guard, some
    # concurrently-launched agents ended up with an empty profile
    # directory and no running Chromium/socat at all.
    #
    # setopt +o nomatch: deskette's login shell is zsh, which by default
    # aborts the whole command with "no matches found" if a glob doesn't
    # match anything (unlike bash, which leaves it as a literal string).
    # Without this, the sweep killed the ENTIRE remote command (and thus
    # this whole wrapper) whenever no /tmp/chromium-agent-* dirs existed —
    # the common case. Same class of bug previously hit and fixed for
    # --remote-allow-origins=*.
    #
    # -n (redirect ssh's stdin from /dev/null) is required on every SSH
    # call in this script except the final playwright-mcp launch. Without
    # it, ssh attaches to and forwards this wrapper's real stdin (the pipe
    # OpenCode uses to send MCP JSON-RPC) to these one-shot remote shell
    # commands, none of which read it. If OpenCode's "initialize" request
    # arrives while any of these earlier ssh calls is still running, it
    # gets silently swallowed here and never reaches playwright-mcp, which
    # then waits forever on an already-drained stdin -- surfacing in
    # OpenCode as "Operation timed out after 30000ms".
    "$SSH_BIN" -n "$USER@$HOST" '
      setopt +o nomatch 2>/dev/null || true
      for dir in /tmp/chromium-agent-*; do
        [ -d "$dir" ] || continue
        if [ -n "$(find "$dir" -maxdepth 0 -mmin -0.5 2>/dev/null)" ]; then continue; fi
        if pgrep -f "user-data-dir=$dir" >/dev/null 2>&1; then continue; fi
        [ -f "$dir/.socat.pid" ] && kill -9 "$(cat "$dir/.socat.pid")" 2>/dev/null
        rm -rf "$dir"
      done
    ' || true

    # Create temp profile on deskette from main profile
    "$SSH_BIN" -n "$USER@$HOST" "
      rm -rf '$REMOTE_TEMP_PROFILE'
      cp -a ~/.config/chromium '$REMOTE_TEMP_PROFILE'
      rm -f '$REMOTE_TEMP_PROFILE/SingletonLock' \
            '$REMOTE_TEMP_PROFILE/SingletonSocket' \
            '$REMOTE_TEMP_PROFILE/SingletonCookie'
    "

    # Launch Chromium on deskette with unique profile and port.
    #
    # Chromium's DevTools server always binds to 127.0.0.1, ignoring
    # --remote-debugging-address entirely (a hardened security default in
    # modern Chromium versions; confirmed by testing — "DevTools listening
    # on ws://127.0.0.1:..." is printed even when --remote-debugging-address
    # is passed a different address). So the agent's CDP port is only ever
    # reachable on deskette's own loopback and needs its own forwarder to
    # be reachable from mishy (or any other machine) over Tailscale — same
    # reason chromium-cdp-forward exists for the persistent instance's
    # fixed port 9222, just per-agent here since the port is random.
    "$SSH_BIN" -n "$USER@$HOST" "
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

    # Wait for CDP to come up
    for i in $(seq 1 20); do
      if ${pkgs.curl}/bin/curl -sf "http://$CDP_IP:$AGENT_PORT/json/version" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

    # NOTE: deliberately NOT using `exec` here. exec would replace this bash
    # process (and its trap handlers) with playwright-mcp, so a SIGTERM sent
    # by the parent (e.g. OpenCode killing the MCP server) would go straight
    # to playwright-mcp and our cleanup below would never run, orphaning the
    # remote Chrome + temp profile on deskette forever.
    #
    # NOTE: the trailing `<&0` is required. Bash automatically redirects an
    # asynchronous (`&`) command's stdin from /dev/null when job control is
    # not active (always true for a non-interactive script like this one),
    # UNLESS the command explicitly redirects its own stdin. playwright-mcp
    # is an MCP stdio server: OpenCode communicates with it over this
    # process's stdin/stdout. Without `<&0`, playwright-mcp silently got
    # /dev/null as stdin, saw immediate EOF, and exited within milliseconds
    # of launching -- every prior "it connects fine but exits instantly"
    # observation in this debugging session was actually this bug, not a
    # CDP/networking problem. Confirmed via isolated repro: backgrounding
    # playwright-mcp without `<&0` exits almost instantly regardless of
    # what real stdin is available; adding `<&0` makes it block correctly
    # on stdin as expected.
    ${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp \
      --cdp-endpoint "http://$CDP_IP:$AGENT_PORT" \
      --caps vision \
      "$@" <&0 &
    PLAYWRIGHT_PID=$!

    # Cleanup local playwright-mcp child + remote Chrome + remote temp
    # profile on exit (normal exit, error, or signal).
    #
    # Uses pkill -f matching on the (unique per-agent) profile path rather
    # than killing just the top-level PID from .pid: a plain `kill` on the
    # main Chromium process does NOT cascade to its renderer/GPU/utility
    # child processes (no SIGKILL propagation to children), so those orphan
    # and keep the profile dir's files open, making rm -rf race or fail.
    # Matching on $REMOTE_TEMP_PROFILE (a unique mktemp-style path per agent)
    # is safe here since it can't collide with other agents' profiles.
    #
    # NOTE: this exit-trap path has been observed to be unreliable in some
    # cases (an unexplained intermittent SSH hang on broad pkill/pgrep-loop
    # commands). The startup-time sweep above is the safety net that
    # guarantees eventual cleanup even if this trap doesn't fire.
    cleanup() {
      kill "$PLAYWRIGHT_PID" 2>/dev/null || true
      "$SSH_BIN" -n "$USER@$HOST" "
        [ -f '$REMOTE_TEMP_PROFILE/.socat.pid' ] && kill -9 \$(cat '$REMOTE_TEMP_PROFILE/.socat.pid') 2>/dev/null
        pkill -9 -f 'user-data-dir=$REMOTE_TEMP_PROFILE' 2>/dev/null || true
        for i in \$(seq 1 10); do
          pgrep -f 'user-data-dir=$REMOTE_TEMP_PROFILE' >/dev/null 2>&1 || break
          sleep 0.3
        done
        rm -rf '$REMOTE_TEMP_PROFILE'
      " || true
    }
    trap cleanup EXIT INT TERM SIGINT SIGTERM

    wait "$PLAYWRIGHT_PID"
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
    # no other layer restricting exposure. Lets deskette itself attach its
    # own OpenCode playwright MCP to its persistent Chromium (see
    # chromium-cdp-launcher in modules/home/niri and
    # playwright-mcp-local-cdp-wrapper / playwright-mcp-agent-wrapper above).
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
  };
}
