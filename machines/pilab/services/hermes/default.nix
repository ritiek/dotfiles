{ config, pkgs, lib, inputs, ... }:

let
  # In-process Claude Code OAuth billing bypass (replaces the meridian proxy).
  # Store dir holds sitecustomize.py + anthropic_billing_bypass.py.
  hermesClaudeAuth = pkgs.callPackage ./patches/claude-auth { };

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

  # XXX: Patch hermes-agent with PR #25995 (Matrix channel_prompts, channel_skill_bindings, topic_as_prompt).
  # Remove once merged and available in the pinned flake input.
  # https://github.com/NousResearch/hermes-agent/pull/25995
  # Patches generated against pinned rev 61268ff7 (0.15.1) since the PR diff
  # does not apply cleanly to the pinned source.
  hermes-agent-patched = (inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.patch ];
    postInstall = (old.postInstall or "") + ''
      sitePackages=$(find $out -path "*/site-packages/gateway/platforms/matrix.py" | head -1 | xargs dirname | xargs dirname | xargs dirname)
      if [ -n "$sitePackages" ]; then
        patch -p1 -d "$sitePackages" < ${./patches/pr-25995/matrix.patch}
        patch -p1 -d "$sitePackages" < ${./patches/pr-25995/config.patch}
      fi
    '';
  });

  # piper-tts built against python312 (nixpkgs defaults to python313).
  # Minimal build: no training, no HTTP server, no alignment extras.
  piperTtsPy312 = pkgs.callPackage (pkgs.path + "/pkgs/by-name/pi/piper-tts/package.nix") {
    python3Packages = pkgs.python312Packages;
    withTrain = false;
    withHTTP = false;
    withAlignment = false;
  };

  # Script run as root ('+' prefix) before hermes starts.
  # Reads system-level sops secrets via config.sops.secrets.<name>.path so the
  # paths are derived from the actual sops declarations rather than hardcoded.
  # Uses append-or-update to preserve keys written by the activation script.
  hermesPopulateMcpEnv = pkgs.writeShellScript "hermes-populate-mcp-env" ''
    set -euo pipefail
    ENV_FILE=/var/lib/hermes/.hermes/.env

    # Append-or-update: remove stale line for key, append fresh value.
    set_env() {
      local key=$1 val=$2
      touch "$ENV_FILE"
      { grep -v "^''${key}=" "$ENV_FILE" || true; } > "$ENV_FILE.mcp_tmp"
      mv "$ENV_FILE.mcp_tmp" "$ENV_FILE"
      printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
    }

    set_env HERMES_MCP_GITHUB_TOKEN        "$(cat ${config.sops.secrets."github.token".path})"
    set_env HERMES_MCP_KARAKEEP_ADDR       "$(cat ${config.sops.secrets."karakeep_api.address".path})"
    set_env HERMES_MCP_KARAKEEP_KEY        "$(cat ${config.sops.secrets."karakeep_api.key".path})"
    set_env HERMES_MCP_PAPERLESS_URL       "$(cat ${config.sops.secrets."paperless.url".path})"
    set_env HERMES_MCP_PAPERLESS_API_KEY   "$(cat ${config.sops.secrets."paperless_api.key".path})"
    set_env HERMES_MCP_PAPERLESS_PUB_URL   "$(cat ${config.sops.secrets."paperless_public.url".path})"
    set_env HERMES_MCP_SEARX_URL           "$(cat ${config.sops.secrets."searx.url".path}).clawsiecats.lol/"

    set_env GROQ_API_KEY             "$(cat ${config.sops.secrets."groq_api.key".path})"
    set_env ELEVENLABS_API_KEY       "$(cat ${config.sops.secrets."elevenlabs_api.key".path})"

    set_env DISCORD_BOT_TOKEN        "$(cat ${config.sops.secrets."discord.bot_token".path})"
    set_env DISCORD_ALLOWED_USERS    "$(cat ${config.sops.secrets."discord.allowed_users".path})"

    chown ritiek:users "$ENV_FILE"
    chmod 0640 "$ENV_FILE"
  '';
in

{
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
    PYTHONPATH = "${hermesClaudeAuth}:${pkgs.python312.withPackages (ps: [ ps.edge-tts ])}/lib/python3.12/site-packages:/var/lib/hermes/.hermes/local-packages";
    HERMES_PATCHES_DIR = "${hermesClaudeAuth}";
    # ffmpeg required for TTS (Edge TTS audio conversion)
    PATH = lib.mkForce (lib.makeBinPath [ pkgs.ffmpeg ] + ":/run/wrappers/bin:/run/current-system/sw/bin");
    LD_LIBRARY_PATH = "${pkgs.gcc-unwrapped.lib}/lib:${pkgs.libopus}/lib";
  };

  # Populate MCP secrets into .hermes/.env before the service starts.
  # Runs as root ('+' prefix) so it can read home-manager sops secret files.
  systemd.services.hermes-agent.serviceConfig.ExecStartPre =
    [ "+${hermesPopulateMcpEnv}" ];

  # Allow the hermes terminal tool to run sudo. The module sets
  # NoNewPrivileges=true (hardening) which blocks setuid binaries like sudo.
  # Override it so ritiek's passwordless sudo access actually works.
  systemd.services.hermes-agent.serviceConfig.NoNewPrivileges = lib.mkForce false;

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

  services.hermes-agent = {
    enable = true;
    package = hermes-agent-patched;

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

    extraDependencyGroups = [ "matrix" "anthropic" ];

    settings = {
      platforms.matrix = {
        enabled = true;
        # Home channel: the room Hermes uses for proactive/unprompted messages
        # (cron jobs, notifications, alerts). Pinned here so it survives a
        # /var/lib/hermes wipe; equivalent to running /sethome in the room.
        home_channel = {
          platform = "matrix";
          chat_id = "!mgJNTDy1P5jtyNla_N-Z54IclPtbdPGCfrSH6wfAzr4";
          name = "ritiek";
        };
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
        platforms.matrix = {
          tool_preview_length = 10000;
          tool_progress = "all";
        };
      };

      model = {
        default = "claude-sonnet-4-6";
        provider = "anthropic";
        base_url = "https://api.anthropic.com";
      };
      terminal = {
        backend = "local";
        timeout = 180;
        lifetime_seconds = 300;
      };
      agent = {
        max_turns = 60;
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      toolsets = [ "all" ];
      security = {
        tirith_enabled = false;
        redact_secrets = false;
      };
      stt = {
        provider = "groq";
      };
      voice = {
        tts_enabled = true;
      };
      tts = {
        provider = "hannah-groq";
        providers.hannah-groq = {
          command = "/var/lib/hermes/.hermes/scripts/groq_tts.sh {input_path} {output_path} {voice} {model}";
          voice = "hannah";
          model = "canopylabs/orpheus-v1-english";
          output_format = "ogg";
          timeout = 30;
        };
      };
      # HA uses SSE transport -- declared in settings.mcp_servers since
      # the typed mcpServers submodule has no transport field.
      mcp_servers.homeassistant = {
        url = "http://pilab.lion-zebra.ts.net:8123/mcp_server/sse";
        transport = "sse";
        headers.Authorization = "Bearer \${HASS_TOKEN}";
      };
    };

    # MCP servers -- secrets injected via ${VAR} interpolation, resolved from
    # .hermes/.env which is populated by hermesPopulateMcpEnv at service start.
    # HASS_TOKEN is already in /run/secrets/hermes.env (via environmentFiles below).
    mcpServers = {
      # -- Remote HTTP servers --
      github = {
        url = "https://api.githubcopilot.com/mcp/";
        headers.Authorization = "Bearer \${HERMES_MCP_GITHUB_TOKEN}";
      };
      # -- Remote HTTP servers (continued) --
      indmoney = {
        url = "https://mcp.indmoney.com/mcp";
        auth = "oauth";
      };
      # -- Stdio servers --
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
      context7 = {
        command = "${mcp-servers-nix.context7-mcp}/bin/context7-mcp";
      };
      karakeep = {
        command = "${pkgs.nodejs_24}/bin/node";
        args = [
          "${pkgs.nodejs_24}/bin/npx"
          "-y"
          "@karakeep/mcp"
        ];
        env = {
          PATH = lib.makeBinPath [ pkgs.nodejs_24 pkgs.bash ];
          KARAKEEP_API_ADDR = "\${HERMES_MCP_KARAKEEP_ADDR}";
          KARAKEEP_API_KEY  = "\${HERMES_MCP_KARAKEEP_KEY}";
        };
        timeout = 60;
      };
      paperless = {
        command = "${pkgs.nodejs_24}/bin/node";
        args = [
          "${pkgs.nodejs_24}/bin/npx"
          "-y"
          "@baruchiro/paperless-mcp@latest"
        ];
        env = {
          PATH = lib.makeBinPath [ pkgs.nodejs_24 pkgs.bash ];
          PAPERLESS_URL        = "\${HERMES_MCP_PAPERLESS_URL}";
          PAPERLESS_API_KEY    = "\${HERMES_MCP_PAPERLESS_API_KEY}";
          PAPERLESS_PUBLIC_URL = "\${HERMES_MCP_PAPERLESS_PUB_URL}";
        };
      };
      kindly-web-search = {
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
            pkgs.uv pkgs.git pkgs.coreutils pkgs.python3 pkgs.chromium
          ];
          GITHUB_TOKEN                          = "\${HERMES_MCP_GITHUB_TOKEN}";
          SEARXNG_BASE_URL                      = "\${HERMES_MCP_SEARX_URL}";
          KINDLY_BROWSER_EXECUTABLE_PATH        = "${pkgs.chromium}/bin/chromium";
          KINDLY_TOOL_TOTAL_TIMEOUT_SECONDS     = "300";
          KINDLY_TOOL_TOTAL_TIMEOUT_MAX_SECONDS = "600";
          KINDLY_WEB_SEARCH_MAX_CONCURRENCY     = "3";
        };
        timeout = 60;
      };
      playwright = {
        command = "${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp";
        args = [
          "--executable-path" "${pkgs.chromium}/bin/chromium"
          "--headless"
          "--caps" "vision"
          "--ignore-https-errors"
          "--viewport-size" "1271x936"
        ];
        timeout = 30;
      };
    };

    environmentFiles = [
      "/run/secrets/hermes.env"
    ];
  };
}

