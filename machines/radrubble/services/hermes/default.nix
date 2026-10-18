{ config, pkgs, lib, inputs, ... }:

let
  # In-process Claude Code OAuth billing bypass (replaces the meridian proxy).
  # Store dir holds sitecustomize.py + anthropic_billing_bypass.py.
  hermesClaudeAuth = pkgs.callPackage ./patches/claude-auth { };

  # Patch for detail: "auto" on image_url blocks — reduces token bloat from
  # full-resolution image tokenization (25-60x reduction).
  # https://github.com/NousResearch/hermes-agent/issues/13065
  hermesDetailAutoOverlay = pkgs.callPackage ./patches/detail-auto { };

  edgeTtsPython = pkgs.python314.withPackages (ps: [ ps.edge-tts ]);

  # The dependency-complete hermes CLI (sealed venv WITH the matrix+anthropic
  # groups) is the package used by the gateway service's ExecStart. The bare
  # `config.services.hermes-agent.package` lacks those deps, so we derive the
  # env-complete store path from the service ExecStart instead.
  hermesEnvCli =
    builtins.head
      (lib.splitString " "
        config.systemd.services.hermes-agent.serviceConfig.ExecStart);

  # Interactive `hermes` wrapper: sets HERMES_HOME (share gateway state) and
  # the bypass env vars (PYTHONPATH + HERMES_PATCHES_DIR) so the TUI routes
  # through the Claude Code subscription just like the gateway service does,
  # then execs the dep-complete CLI. Scoped to hermes only -- does NOT pollute
  # other Python tools the way a global PYTHONPATH would.
  hermesWrapped = pkgs.writeShellScriptBin "hermes" ''
    export HERMES_HOME=/var/lib/hermes/.hermes
    export PYTHONPATH=${hermesClaudeAuth}
    export HERMES_PATCHES_DIR=${hermesClaudeAuth}
    exec ${hermesEnvCli} "$@"
  '';

  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # Prebuilt kitten_tts_rs (aarch64) binaries: `kitten-tts` CLI +
  # `kitten-tts-server` (OpenAI-compatible /v1/audio/speech). autoPatchelf'd.
  kittenTtsRs = pkgs.callPackage ./pkgs/kitten-tts-rs { };

  # Local Moonshine TINY STT server (OpenAI-compatible /v1/audio/transcriptions).
  # Loads the model once on startup and keeps it hot. Bound on 127.0.0.1:7258.
  moonshineSttServer = pkgs.callPackage ./pkgs/moonshine-stt-server { };

  # The nano-int8 KittenTTS model dir (25MB). The package output IS the model
  # directory (config.json, *.onnx, voices.npz at its root).
  kittenTtsModel = pkgs.callPackage ./pkgs/kitten-tts-nano-int8 { };

  # Command-type TTS provider wrapper. hermes runs this once per voice reply:
  # it curls the warm kitten-tts-server for the audio (writing {output_path}
  # which hermes then uploads to Matrix) AND plays it on the Bluetooth speaker
  # as a side effect. Playback is backgrounded (non-blocking) so the audio's
  # duration is not added to the conversation turn latency.
  #   $1 = {input_path}  -- temp UTF-8 file containing the reply text
  #   $2 = {output_path} -- where hermes expects the audio (ogg/opus)
  #   $3 = {voice}       -- kitten voice name (e.g. Rosie)
  # Notes:
  #   * curls 127.0.0.1:7257 (the same warm server the openai provider used) so
  #     the model stays resident -- no per-call cold load.
  #   * response_format=opus -> audio/ogg, exactly what Matrix voice bubbles want.
  #   * jq -Rs builds a JSON-safe body (handles quotes/newlines in the reply).
  #   * pw-play needs XDG_RUNTIME_DIR to reach ritiek's (uid 1000) PipeWire; the
  #     speaker is pinned by stable node.name so default-sink changes don't matter.
  # Plays $1 on the BT speaker at speakerVolume (0-1.0), then puts the
  # speaker's volume back. The speaker keeps one volume for both multipoint
  # connections (e.g. mishy's) and only tells us its current level ~3s after
  # it switches to our stream, so play silence until that arrives, else we'd
  # restore a stale level and change the other device's volume.
  speakerVolume = 0.45;
  speakerPlay = pkgs.writeShellScript "speaker-play" ''
    export XDG_RUNTIME_DIR=/run/user/1000
    mac=$(cat ${config.sops.secrets."bt_speaker.mac_address".path})
    node="bluez_output.$mac.1"
    hw=${toString (builtins.floor (speakerVolume * 127 + 0.5))}  # AVRCP 0-127
    busctl=${pkgs.systemd}/bin/busctl
    pwcat=${pkgs.pipewire}/bin/pw-cat
    # One reply at a time, so the volume saved below is never our own.
    exec 9>"$XDG_RUNTIME_DIR/speaker-play.lock"
    ${pkgs.util-linux}/bin/flock 9
    # The BlueZ transport has the exact 0-127 value; wpctl rounds it to 2
    # decimals, which nudges the speaker a step up on every restore.
    tp=$($busctl --list tree org.bluez | grep -m1 "/org/bluez/hci0/dev_$mac/sep[0-9]*/fd[0-9]*$")
    [ -n "$tp" ] || exit 1
    vol() { $busctl get-property org.bluez "$tp" org.bluez.MediaTransport1 Volume | cut -d' ' -f2; }
    setvol() { $busctl set-property org.bluez "$tp" org.bluez.MediaTransport1 Volume q "$1"; }
    prev=$(vol)
    $pwcat -p --raw --format s16 --rate 48000 --channels 2 --target "$node" - < /dev/zero & keep=$!
    trap 'kill $keep' EXIT
    # No change within ~6s: the speaker's level is still the one we have.
    for _ in $(seq 25); do
      sleep 0.2
      cur=$(vol)
      [ "$cur" = "$prev" ] || { prev=$cur; break; }
    done
    setvol $hw
    $pwcat -p --target "$node" "$1" & play=$!
    while kill -0 $play 2>/dev/null; do
      sleep 0.2
      # A late level from the speaker: remember it, then put ours back.
      cur=$(vol)
      [ "$cur" = $hw ] || { prev=$cur; setvol $hw; }
    done
    # Restore while our stream still holds the speaker, so it takes.
    setvol "$prev"
    sleep 1
  '';

  kittenLocalTts = pkgs.writeShellScriptBin "kitten-local-tts" ''
    set -eu
    in="$1"; out="$2"; voice="$3"
    ${pkgs.curl}/bin/curl -fsS -X POST http://127.0.0.1:7257/v1/audio/speech \
      -H 'Content-Type: application/json' \
      --data "$(${pkgs.jq}/bin/jq -Rs --arg v "$voice" \
        '{input: ., voice: $v, response_format: "opus"}' < "$in")" \
      -o "$out"
    # Play on the BT speaker, non-blocking. Failures here must not fail the
    # provider (hermes still needs $out for the Matrix upload), so guard it.
    ${speakerPlay} "$out" >/dev/null 2>&1 &
    exit 0
  '';

  # Same contract as kittenLocalTts, but synthesises on radrubble's NPU via
  # paroli (Piper en_US-kristin-medium). $3 (voice) is ignored: single speaker.
  paroliTts = pkgs.writeShellScriptBin "paroli-tts" ''
    set -eu
    in="$1"; out="$2"
    ${pkgs.curl}/bin/curl -fsS -X POST http://radrubble.lion-zebra.ts.net:7257/api/v1/synthesise \
      -H 'Content-Type: application/json' \
      --data "$(${pkgs.jq}/bin/jq -Rs '{text: ., audio_format: "opus"}' < "$in")" \
      -o "$out"
    ${speakerPlay} "$out" >/dev/null 2>&1 &
    exit 0
  '';

in

{
  sops.secrets."bt_speaker.mac_address" = { owner = "ritiek"; };

  # A speaker that is already on while radrubble boots doesn't reconnect by
  # itself, so dial it for ~10 min after boot (the sleep comes first so
  # wireplumber has registered its A2DP endpoints). Switched on later, the
  # speaker connects to us on its own.
  systemd.user.services.bt-speaker-connect = {
    wantedBy = [ "default.target" ];
    after = [ "wireplumber.service" ];
    unitConfig.ConditionUser = "ritiek";
    script = ''
      mac=$(tr _ : < ${config.sops.secrets."bt_speaker.mac_address".path})
      for _ in $(seq 20); do
        sleep 30
        # Output names the MAC, which is kept in sops; keep it out of the journal.
        timeout 30 ${config.hardware.bluetooth.package}/bin/bluetoothctl connect "$mac" >/dev/null 2>&1 && exit 0
      done
    '';
  };

  # The wrapper is the sole `hermes` on PATH (we do NOT use the module's
  # addToSystemPackages CLI, which would shadow this wrapper and skip the
  # billing bypass). Export HERMES_HOME system-wide so non-hermes tooling and
  # already-correct shells still see it.
  environment.systemPackages = [ hermesWrapped pkgs.libopus ];
  environment.variables.HERMES_HOME = "/var/lib/hermes/.hermes";

  # Inject the bypass at the Python interpreter level:
  #   PYTHONPATH         -> so sitecustomize.py runs at interpreter startup
  #   HERMES_PATCHES_DIR -> so the import hook finds anthropic_billing_bypass.py
  # Scoped to the gateway service only (a global PYTHONPATH would inject this
  # into every Python program on the system).
  systemd.services.hermes-agent.environment = {
    HERMES_DETAIL_AUTO_OVERLAY_DIR = "${hermesDetailAutoOverlay}";
    # edgeTtsPython must match hermes' interpreter (pm/lock.json in hermes-agent).
    PYTHONPATH = "${hermesClaudeAuth}:${edgeTtsPython}/${edgeTtsPython.sitePackages}:/var/lib/hermes/.hermes/local-packages";
    HERMES_PATCHES_DIR = "${hermesClaudeAuth}";
    # ffmpeg required for TTS (Edge TTS audio conversion).
    # claude-code: hermes sends `claude --version` as the OAuth client version
    # (falls back to 2.1.74 if not found); Opus 5.5 needs >= 2.1.280.
    PATH = lib.mkForce (lib.makeBinPath [
      pkgs.ffmpeg
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ] + ":/run/wrappers/bin:/run/current-system/sw/bin");
    LD_LIBRARY_PATH = "${pkgs.gcc-unwrapped.lib}/lib:${pkgs.libopus}/lib";
    # Kept for the (now commented) openai TTS provider: the openai python client
    # refuses to initialise without a non-empty key. Harmless while the active
    # provider is the kitten-local command wrapper; leave it so re-enabling the
    # openai block needs no further change.
    OPENAI_API_KEY = "sk-local-kitten-dummy";
    MATRIX_DM_AUTO_THREAD = "true";
    MATRIX_HOME_ROOM = "!H1PCpqBZygxcuIbrB3qiA0hEeKTa7FBmsQt2NjWhw9k";
    # Hermes 0.21.0 dispatches cron workers into a transient systemd *user*
    # scope (`systemd-run --user --scope`) so they survive a gateway restart
    # (runs the worker outside the gateway cgroup to avoid OOM-killing the whole
    # gateway). That call fail-CLOSES when it can't reach the user bus: without
    # these, cron execution dies with "systemd-run --user --scope is unavailable"
    # and crons silently stop firing. The systemd hermes-agent unit doesn't
    # inherit a login session's XDG_RUNTIME_DIR/DBUS address, so point them at
    # ritiek's (uid 1000) lingering user manager (`loginctl enable-linger` keeps
    # /run/user/1000 alive without an interactive login).
    XDG_RUNTIME_DIR = "/run/user/1000";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
    # Kill the MESSAGING_CWD deprecation warning. The hermes-agent nix module
    # injects this system-wide via cfg.workingDirectory, even for users who
    # configure terminal.cwd properly. Override to empty so hermes doesn't
    # print "MESSAGING_CWD is deprecated" on every startup.
    MESSAGING_CWD = lib.mkForce "";
  };

  # Allow the hermes terminal tool to run sudo. The module sets
  # NoNewPrivileges=true (hardening) which blocks setuid binaries like sudo.
  # Override it so ritiek's passwordless sudo access actually works.
  systemd.services.hermes-agent.serviceConfig.NoNewPrivileges = lib.mkForce false;

  # Share ritiek's Claude Code login with hermes (HOME=/var/lib/hermes, and hermes
  # hardcodes ~/.claude/.credentials.json). Link the whole dir, not the file:
  # hermes writes refreshed tokens via temp file + rename, which would replace a
  # file symlink. ProtectSystem=strict makes /home read-only, hence ReadWritePaths.
  # The dir must exist or the unit fails at mount namespace setup.
  systemd.tmpfiles.rules = [
    "d /home/ritiek/.claude 0755 ritiek users -"
    "L+ /var/lib/hermes/.claude - - - - /home/ritiek/.claude"
  ];
  systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [ "/home/ritiek/.claude" ];

  # Local KittenTTS server (kitten_tts_rs, Rust) exposing an OpenAI-compatible
  # /v1/audio/speech endpoint. hermes' built-in `openai` TTS provider points at
  # this (base_url below). Keeping the model warm in a long-lived process avoids
  # the ~2s cold-load on every reply. Bound on 0.0.0.0:7257 (no auth) per intent
  # -- reachable over Tailscale/LAN.
  # Voice runs on the NPU (../voice): paroli-tts on :7257, whisper-stt on :7258.
  # kitten-tts-server and moonshine-stt-server below are CPU fallbacks on the
  # same ports; stop the NPU unit before starting one.

  systemd.services.kitten-tts-server = {
    description = "KittenTTS server (OpenAI-compatible TTS for hermes)";
    # wantedBy intentionally omitted: started on-demand by hermes-agent (lazy start).
    after = [ "network.target" ];
    # espeak-ng is required at runtime for phonemization.
    path = [ pkgs.espeak-ng ];
    environment = {
      # Silence ONNX Runtime's default info-level log spam (3 = WARNING).
      ORT_LOGGING_LEVEL = "3";
    };
    serviceConfig = {
      ExecStart = "${kittenTtsRs}/bin/kitten-tts-server ${kittenTtsModel} --host 0.0.0.0 --port 7257";
      Restart = "on-failure";
      RestartSec = 2;
      DynamicUser = true;
      # Hardening (server only reads its model dir + listens on a socket).
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  systemd.services.moonshine-stt-server = {
    description = "Moonshine TINY STT server (OpenAI-compatible, for hermes)";
    after = [ "network.target" ];
    environment = {
      MOONSHINE_MODEL    = "TINY";
      MOONSHINE_STT_PORT = "7258";
      MOONSHINE_STT_HOST = "127.0.0.1";
      # Silence ONNX Runtime info-level log spam (3 = WARNING).
      ORT_LOGGING_LEVEL  = "3";
      HOME               = "/home/ritiek";
      # Writable model cache (ProtectHome makes ~/.cache read-only).
      MOONSHINE_VOICE_CACHE = "/var/cache/moonshine-stt";
    };
    serviceConfig = {
      ExecStart      = "${moonshineSttServer}/bin/moonshine-stt-server";
      User           = "ritiek";
      Group          = "users";
      CacheDirectory = "moonshine-stt";
      Restart        = "on-failure";
      RestartSec     = 3;
      ProtectSystem  = "strict";
      ProtectHome    = "read-only";
      PrivateTmp     = true;
      NoNewPrivileges = true;
    };
  };

  # Give the gateway enough stop time to finish its drain. The module ships
  # TimeoutStopSec=90s but the gateway's drain_timeout is 180s, so systemd
  # SIGKILLs it mid-drain on stop/rebuild -> dirty exit code 1 (the unit then
  # stays failed). 210s = drain_timeout + headroom, per the gateway's own
  # startup warning.
  systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = lib.mkForce 210;

  # Self-rebuild suicide guard. Hermes runs `nixos-rebuild switch` as its own
  # terminal tool; the rebuild's final `systemctl restart hermes-agent` SIGTERMs
  # the hermes-agent.service cgroup, killing the in-flight rebuild mid-activation
  # so the restart cycle only does STOP and never completes START -> unit failed.
  # restartIfChanged=false leaves the running process untouched on rebuild (new
  # config is staged but not switched into this unit), so nothing hermes does can
  # restart-kill itself, regardless of how it invokes the rebuild (sudo, absolute
  # path, etc. -- a PATH shim cannot win that). stopIfChanged=false keeps the
  # same single-restart semantics off for the stop path too.
  # TRADE-OFF: changes to THIS unit no longer auto-apply on rebuild; apply them
  # manually from a non-hermes shell: `sudo systemctl restart hermes-agent`.
  systemd.services.hermes-agent.restartIfChanged = false;
  systemd.services.hermes-agent.stopIfChanged = false;

  # Voice-note turns scan the whole messages table in state.db before replying;
  # once the DB fragments that takes ~70s cold on the microSD instead of ~3s.
  # Defragment monthly (FTS merge + VACUUM, deletes nothing). optimize refuses
  # while the gateway holds state.db, so hermes is down for the run (~20 min).
  systemd.services.hermes-sessions-optimize = {
    startAt = "*-*-01 04:00:00";
    environment.HOME = "/var/lib/hermes";
    serviceConfig = {
      Type = "oneshot";
      User = "ritiek";
      WorkingDirectory = "/var/lib/hermes";
      Nice = 10;
      IOSchedulingClass = "idle";
      ExecStartPre = "+${pkgs.systemd}/bin/systemctl stop hermes-agent.service";
      ExecStart = "${hermesWrapped}/bin/hermes sessions optimize";
      # Runs on failure too, so hermes always comes back.
      ExecStopPost = "+${pkgs.systemd}/bin/systemctl start hermes-agent.service";
    };
  };

  # Dashboard unit stays defined but doesn't autostart; run it on demand with
  # `sudo systemctl start hermes-backend`.
  systemd.services.hermes-backend.wantedBy = lib.mkForce [ ];

  # ── Hermes Agent gateway daemon ─────────────────────────────────────
  services.hermes-agent = {
    enable = true;

    # NOTE: addToSystemPackages is intentionally NOT set. It would add the bare
    # dep-complete CLI to PATH and shadow our hermesWrapped wrapper (collision
    # winner is nondeterministic / favors the module), bypassing the billing
    # bypass. The wrapper above already provides `hermes` + HERMES_HOME.

    # Run the service as the ritiek user (not the dedicated `hermes` system
    # user) so it directly owns its state and Claude OAuth creds, avoiding
    # cross-user permission glitches. ritiek already exists, so don't let the
    # module try to create it.
    user = "ritiek";
    group = "users";
    createUser = false;

    # Upstream's flake builds with version 0.0.0, which fails every plugin's
    # requires_hermes check (homeassistant left core and needs >=0.21.5).
    # ponytail: hand-set, bump with the hermes-agent input (locked rev is
    # v0.22.1 + 23 commits).
    package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      version = "0.22.1";
    };

    extraDependencyGroups = [ "matrix" "anthropic" ];

    # Web dashboard as a separate hermes-backend unit (http://127.0.0.1:9119).
    # Loopback only: any other bind engages the auth gate and needs
    # dashboard.basic_auth credentials in settings.
    backend.mode = "dashboard";

    # Make config.yaml fully Nix-managed (declarative, no imperative drift).
    #
    # By default the module MERGES `settings` into the existing config.yaml via
    # nix/configMergeScript.nix, which does deep_merge(existing, nix): Nix keys
    # win, but keys absent from Nix are NEVER deleted. So commenting a block out
    # here left it live in config.yaml forever -- that is how a superseded
    # `auxiliary.vision` block silently forced image routing to "text" mode, and
    # how the superseded tts.openai / tts.providers.hannah-groq blocks below
    # lingered after being commented out.
    #
    # Setting `configFile` makes activation `install` this file over config.yaml
    # instead of merging, so removing a key here actually removes it. The result
    # is still a real writable file (mode 0640, not a store symlink), so hermes
    # can write to it at runtime -- but any such write is reset on next rebuild.
    # Consequence: settings changed via the TUI must be recorded here to persist.
    configFile = pkgs.writeText "hermes-config.yaml" (
      builtins.toJSON config.services.hermes-agent.settings
    );

    settings = {
      platforms.webhook = {
        enabled = true;
        host = "0.0.0.0";
        port = 8644;
        # secret = "${WEBHOOK_SECRET}";
      };
      platforms.matrix = {
        enabled = true;
        topic_as_prompt = true;
        # Home channel: the room Hermes uses for proactive/unprompted messages
        # (cron jobs, notifications, alerts). Pinned here so it survives a
        # /var/lib/hermes wipe; equivalent to running /sethome in the room.
        home_channel = {
          platform = "matrix";
          chat_id = "!H1PCpqBZygxcuIbrB3qiA0hEeKTa7FBmsQt2NjWhw9k";
          name = "ritiek";
        };
        # Per-room model. `/model` in the room still wins for that session.
        # Reasoning effort is per-model: see agent.reasoning_overrides.
        channel_overrides."!DhGz4cPBPFmEUlVLeO5-jjWiSG2_5Vr0qcD2yCvzuc4" = {
          model = "claude-opus-5-5";
          provider = "anthropic";
        };
      };
      platforms.homeassistant = {
        enabled = true;
        # HASS_TOKEN in the env unconditionally activates this platform.
        # Without watch_* filters Hermes drops all state_changed events
        # and logs a warning at startup.
        #
        # Current: no-op sentinel — silences the warning without
        # forwarding any real events to the agent.
        #
        # To receive events, replace with e.g.:
        #   extra = {
        #     watch_domains = [
        #       "climate" "binary_sensor" "alarm_control_panel"
        #       "light" "lock" "switch"
        #     ];
        #     watch_entities = [
        #       "sensor.front_door_battery"
        #     ];
        #     ignore_entities = [
        #       "sensor.uptime" "sensor.cpu_usage"
        #     ];
        #     cooldown_seconds = 30;
        #   };
        extra = {
          watch_entities = [ "sensor.__hermes_noop__" ];
        };
      };
      platforms.discord = {
        enabled = false;
      };

      # Tool call display in Matrix messages.
      # tool_progress="all" shows plain-text primary-arg preview (no JSON).
      # tool_preview_length=10000 disables the 40-char default truncation.
      # Global tier-2 key needed too: hermes 0.15.1 stores the preview cap in a
      # process-wide global that every _run_agent call overwrites with ITS own
      # platform value. Background/non-matrix runs (memory, user_profile) would
      # otherwise stomp it to 0/40 and cut the next matrix bubble. A tier-2
      # global outranks all per-platform tier-3 defaults so nothing stomps below.
      display = {
        tool_preview_length = 10000;
        # How the agent handles messages received while it's busy running a task.
        # interrupt — new message stops the current task immediately (default)
        # queue     — message is queued until the current task finishes
        # steer     — message is injected mid-run after the next tool call
        busy_input_mode = "steer";
        platforms.webhook = {
          enabled = true;
          host = "0.0.0.0";
          port = 8644;
        # secret = "${WEBHOOK_SECRET}";
        };
        platforms.matrix = {
          tool_preview_length = 10000;
          tool_progress = "all";
        };
      };

      model = {
        # default = "nemotron-3-ultra-free";
        # default = "opencode/deepseek-v4-flash-free";
        # default = "opencode-go/gpt-5.6-luna";
        # default = "opencode-go/qwen3.7-plus";
        # default = "opencode-go/mimo-v2.5";
        # default = "opencode-go/glm-5.3-flash";
        default = "gpt-6-luna";
        provider = "github-copilot";
        # Multimodal. Auth: COPILOT_GITHUB_TOKEN/GH_TOKEN (gho_/github_pat_, NOT
        # classic ghp_) or `hermes auth add github-copilot` (device flow).
        supports_vision = true;

        # Previous: opencode free tier (keyless, fixed X-Session-ID).
        # default = "mimo-v2.5-free";
        # provider = "opencode";
        # base_url = "https://opencode.ai/zen/v1";
        # default_headers = {
        #   "Authorization" = "";
        #   "HTTP-Referer" = "https://opencode.ai/";
        #   "X-Title" = "opencode";
        #   "User-Agent" = "opencode/0.20.5";
        #   "X-Session-ID" = "hermes-c5c231f4-db63-4992-a75d-001e0e40bb4b";
        # };

        # default = "claude-sonnet-4-6";
        # provider = "anthropic";
        # base_url = "https://api.anthropic.com";
      };
      terminal = {
        backend = "local";
        cwd = "/var/lib/hermes/workspace";
        timeout = 180;
        lifetime_seconds = 300;
      };
      agent = {
        # Effectively unlimited. There is no "unlimited" sentinel upstream:
        # agent/conversation_loop.py gates on `api_call_count < max_iterations`
        # and IterationBudget.consume() stops at `_used >= max_total`, so 0 or
        # -1 would mean *zero* API calls, not infinite. A large int is the
        # upstream idiom for this (agent/curator.py uses max_iterations=9999).
        #
        # Raised from 60 on 2026-08-08: the Hinge review workflow hit 60/60
        # mid-task twice, once leaving a decided LIKE unexecuted and AGENTS.md
        # unpatched. A single profile costs ~20-30 turns.
        max_turns = 9999;
        # Per-model effort (beats global agent.reasoning_effort).
        reasoning_overrides."claude-opus-5-5" = "high";
      };
      compression = {
        enabled = true;
        # Trigger at 50% of context window (500K tokens for 1M model)
        threshold = 0.50;
        # Compress middle to 20% of threshold after firing
        target_ratio = 0.20;
        # Protect last 20 messages from summarization
        protect_last_n = 20;
        # Protect first 3 turns + system prompt from summarization
        protect_first_n = 3;
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      auxiliary = {
        # vision = {
        #   provider = "opencode-go";
        #   # model = "mimo-v2.5";
        #   model = "qwen3.7-plus";
        #   base_url = "https://opencode.ai/zen/go/v1";
        #   api_key = "\${OPENCODE_GO_API_KEY}";
        # };
        # title_generation = {
        #   provider = "opencode-go";
        #   model = "deepseek-v4-flash";
        #   base_url = "https://opencode.ai/zen/go/v1";
        #   api_key = "\${OPENCODE_GO_API_KEY}";
        # };
        # compression = {
        #   provider = "opencode-go";
        #   model = "deepseek-v4-flash";
        #   base_url = "https://opencode.ai/zen/go/v1";
        #   api_key = "\${OPENCODE_GO_API_KEY}";
        # };
      };

      toolsets = [ "all" ];
      security = {
        tirith_enabled = false;
        redact_secrets = false;
      };
      # Previous STT provider (Groq Whisper API). Superseded by the local
      # Moonshine TINY server; kept commented for easy rollback.
      # stt = {
      #   provider = "groq";
      # };
      # Whisper tiny on the NPU (../voice). moonshine-stt-server is the CPU
      # fallback on the same port; both ignore the model name.
      stt = {
        provider = "openai";
        openai = {
          base_url = "http://127.0.0.1:7258/v1";
          api_key  = "local";
          model    = "whisper-tiny";
        };
      };
      voice = {
        tts_enabled = true;
      };
      # Runtime-set onboarding flag, declared here so the now-authoritative
      # config.yaml overwrite doesn't re-trigger the one-off prompt each rebuild.
      onboarding.seen.busy_input_prompt = true;
      # TTS via a command-wrapper around the warm local kitten-tts-server.
      # The wrapper (kittenLocalTts) curls 127.0.0.1:7257 for the audio AND
      # plays it on the Bluetooth speaker (backgrounded). hermes still uploads
      # {output_path} as a Matrix voice message, so speaker playback mirrors
      # exactly the voice messages hermes already sends.
      # Active: paroli-radrubble (Piper Kristin on radrubble's NPU). Set
      # provider back to "kitten-local" to roll back.
      tts = {
        provider = "paroli-radrubble";
        providers.paroli-radrubble = {
          command = "${paroliTts}/bin/paroli-tts {input_path} {output_path} {voice}";
          voice = "kristin";
          output_format = "ogg";
          timeout = 30;
        };
        providers.kitten-local = {
          command = "${kittenLocalTts}/bin/kitten-local-tts {input_path} {output_path} {voice}";
          voice = "Rosie";
          output_format = "ogg";
          timeout = 30;
        };
      };
      # Previous TTS provider: hermes' built-in `openai` provider pointed at the
      # local kitten-tts-server (no local speaker playback). Superseded by the
      # kitten-local command wrapper above; kept commented for reference.
      # tts = {
      #   provider = "openai";
      #   openai = {
      #     base_url = "http://127.0.0.1:7257/v1";
      #     model = "kitten-tts-nano-int8";
      #     voice = "Luna";
      #   };
      # };
      # Previous TTS provider (Groq-hosted Orpheus via a shell-command provider).
      # Superseded by the local kitten-tts-server above; kept commented for reference.
      # tts = {
      #   provider = "hannah-groq";
      #   providers.hannah-groq = {
      #     command = "/var/lib/hermes/.hermes/scripts/groq_tts.sh {input_path} {output_path} {voice} {model}";
      #     voice = "hannah";
      #     model = "canopylabs/orpheus-v1-english";
      #     output_format = "ogg";
      #     timeout = 30;
      #   };
      # };
      # HA uses SSE transport -- declared in settings.mcp_servers since
      # the typed mcpServers submodule has no transport field.
      # Disabled plugins: skip import at startup.
      # google_chat-platform raises Platform("google_chat") at import level
      # (adapter.py:129) — `_missing_()` should resolve it via
      # _scan_bundled_plugin_platforms() but fails at runtime. Disable
      # to suppress the "not a valid Platform" warning.
      plugins.disabled = [ "google_chat-platform" ];
      # Catalog plugin, installed at runtime into .hermes/plugins/ by
      # `hermes plugins install homeassistant` (formerly core). Enabled here
      # because `--enable` fails on Nix installs (it resolves deps against a
      # uv.lock the store path doesn't ship).
      plugins.enabled = [ "homeassistant" ];

      mcp_servers.homeassistant = {
        enabled = true;
        url = "http://radrubble.lion-zebra.ts.net:8123/mcp_server/sse";
        transport = "sse";
        headers.Authorization = "Bearer \${HASS_TOKEN}";
      };
    };

    # MCP servers -- secrets injected via ${VAR} interpolation, resolved from
    # .hermes/.env which is seeded at activation time via environmentFiles.
    # HASS_TOKEN is already in /run/secrets/hermes.env (via environmentFiles below).
    mcpServers = {
      # -- Stdio servers --
      # connect_timeout: the default 60s is too short for these to start on
      # radrubble's A55 cores (paperless and kindly-web-search also fetch
      # their package on every start).
      nixos = {
        enabled = true;
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        args = [ ];
        connect_timeout = 180;
      };
      context7 = {
        enabled = true;
        command = "${mcp-servers-nix.context7-mcp}/bin/context7-mcp";
        args = [ ];
      };
      paperless = {
        enabled = true;
        command = "${pkgs.nodejs_24}/bin/node";
        args = [
          "${pkgs.nodejs_24}/bin/npx"
          "-y"
          "@baruchiro/paperless-mcp@latest"
        ];
        env = {
          PATH = lib.makeBinPath [
            pkgs.nodejs_24
            pkgs.bash
          ];
          PAPERLESS_URL        = "\${HERMES_MCP_PAPERLESS_URL}";
          PAPERLESS_API_KEY    = "\${HERMES_MCP_PAPERLESS_API_KEY}";
          PAPERLESS_PUBLIC_URL = "\${HERMES_MCP_PAPERLESS_PUB_URL}";
        };
        connect_timeout = 180;
      };
      kindly-web-search = {
        enabled = true;
        command = "${pkgs.uv}/bin/uvx";
        args = [
          "--refresh"
          "--from"
          "git+https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server"
          "kindly-web-search-mcp-server"
          "start-mcp-server"
        ];
        env = {
          PATH = lib.makeBinPath [
            pkgs.uv
            pkgs.git
            pkgs.coreutils
            pkgs.python3
            # aarch64: stable pkgs.chromium has no binary cache and would
            # build from source (~100GB scratch). unstable nixpkgs has a cached
            # aarch64 build, so use it.
            pkgs.unstable.chromium
          ];
          GITHUB_TOKEN                          = "\${HERMES_MCP_GITHUB_TOKEN}";
          SEARXNG_BASE_URL                      = "\${HERMES_MCP_SEARX_URL}";
          KINDLY_BROWSER_EXECUTABLE_PATH        = "${pkgs.unstable.chromium}/bin/chromium";
          KINDLY_TOOL_TOTAL_TIMEOUT_SECONDS     = "300";
          KINDLY_TOOL_TOTAL_TIMEOUT_MAX_SECONDS = "600";
          KINDLY_WEB_SEARCH_MAX_CONCURRENCY     = "3";
        };
        timeout = 60;
        connect_timeout = 180;
      };
      playwright = {
        enabled = true;
        command = "${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp";
        args = [
          "--executable-path" "${pkgs.unstable.chromium}/bin/chromium"
          "--headless"
          "--caps" "vision"
          "--ignore-https-errors"
          "--viewport-size" "1271x936"
        ];
        timeout = 30;
      };
      # -- Remote HTTP servers --
      github = {
        enabled = true;
        url = "https://api.githubcopilot.com/mcp/";
        headers.Authorization = "Bearer \${HERMES_MCP_GITHUB_TOKEN}";
      };
      indmoney = {
        enabled = true;
        url = "https://mcp.indmoney.com/mcp";
        auth = "oauth";
      };
      swiggy-food = {
        enabled = true;
        url = "https://mcp.swiggy.com/food";
        auth = "oauth";
      };
      swiggy-instamart = {
        enabled = true;
        url = "https://mcp.swiggy.com/im";
        auth = "oauth";
      };
      swiggy-dineout = {
        enabled = true;
        url = "https://mcp.swiggy.com/dineout";
        auth = "oauth";
      };
    };

    environmentFiles = [
      config.sops.secrets."hermes.env".path
      config.sops.templates."hermes-opencode-go-env".path
      config.sops.templates."hermes-mcp-env".path
    ];
  };

  # MCP server secrets rendered from sops at activation time.
  # Seeded into $HERMES_HOME/.env via environmentFiles above.
  sops.templates."hermes-mcp-env" = {
    # Seeded into the agent's environment at unit start, so a rotated API key
    # is only picked up on restart.
    restartUnits = [ "hermes-agent.service" ];
    content = ''
      HERMES_MCP_GITHUB_TOKEN=${config.sops.placeholder."github.token"}
      HERMES_MCP_PAPERLESS_URL=${config.sops.placeholder."paperless.url"}
      HERMES_MCP_PAPERLESS_API_KEY=${config.sops.placeholder."paperless_api.key"}
      HERMES_MCP_PAPERLESS_PUB_URL=${config.sops.placeholder."paperless_public.url"}
      HERMES_MCP_SEARX_URL=${config.sops.placeholder."searx.url"}.clawsiecats.omg.lol/
      GROQ_API_KEY=${config.sops.placeholder."groq_api.key"}
      ELEVENLABS_API_KEY=${config.sops.placeholder."elevenlabs_api.key"}
      OPENCODE_ZEN_API_KEY=${config.sops.placeholder."opencode_api.key"}
    '';
  };

  sops.templates."hermes-opencode-go-env" = {
    restartUnits = [ "hermes-agent.service" ];
    content = ''
      OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode_api.key"}
    '';
  };
}
