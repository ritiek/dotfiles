{ osConfig, config, pkgs, inputs, lib, hostName, ... }:
let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  isNiriEnabled = builtins.any (pkg: pkg.pname or "" == "niri") config.home.packages;

  secretsFile =
    if hostName == "mishy-usb"
    then ./../../machines/mishy/home/${config.home.username}/secrets.yaml
    else ./../../machines/${hostName}/home/${config.home.username}/secrets.yaml;
  secretsContent = builtins.readFile secretsFile;
  hasZaiApiKey = lib.strings.hasInfix "z_ai_api.key:" secretsContent;

   # Patched meridian that strips Claude Code detection triggers from system prompts.
   # Triggers: github.com/*/opencode URLs and <env>...</env> XML blocks.
   meridian-patched = pkgs.stdenv.mkDerivation {
    pname = "meridian-patched";
    version = "1.38.0";
    src = inputs.meridian.packages.${pkgs.stdenv.hostPlatform.system}.meridian;
    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [ pkgs.nodejs_22 ];
    installPhase = ''
      cp -r $src $out
      chmod -R u+w $out

      # Patch cli-fhhxrkyc.js to strip detection triggers from system prompts
      export OUT="$out"
      node << 'PATCH_EOF'
        const fs = require('fs');
        const f = process.env.OUT + '/lib/meridian/dist/cli-fhhxrkyc.js';
        let c = fs.readFileSync(f, 'utf8');
        // Patch 1: OpenAI-format path (result.system = systemPrompt)
        const before1 = 'result.system = systemPrompt;';
        const after1 = [
          'result.system = systemPrompt',
          '  .replace(/https:\\/\\/github\\.com\\/[^\\/\\s]+\\/opencode\\b/g, "")',
          '  .replace(/<env>[\\s\\S]*?<\\/env>/g, "");'
        ].join('\n    ');
        if (!c.includes(before1)) { console.error("PATCH1 FAILED: target string not found"); process.exit(1); }
        c = c.replace(before1, after1);
        console.log('Patched cli-fhhxrkyc.js patch1 OK');

        // Patch 2: Anthropic-format path (systemContext from body.system array)
        const before2 = 'const adapterTransforms = getAdapterTransforms(adapter.name);';
        const after2 = [
          'systemContext = systemContext',
          '  .replace(/https:\\/\\/github\\.com\\/[^\\/\\s]+\\/opencode\\b/g, "")',
          '  .replace(/<env>[\\s\\S]*?<\\/env>/g, "");',
          'const adapterTransforms = getAdapterTransforms(adapter.name);'
        ].join('\n        ');
        if (!c.includes(before2)) { console.error("PATCH2 FAILED: target string not found"); process.exit(1); }
        c = c.replace(before2, after2);
        fs.writeFileSync(f, c);
        console.log('Patched cli-fhhxrkyc.js patch2 OK');
PATCH_EOF

      # Fix bin/meridian wrapper to point to patched cli.js in $out
      printf '#! %s/bin/bash -e\nexec "%s/bin/node" "%s/lib/meridian/dist/cli.js" "$@"\n' \
        "${pkgs.bash}" "${pkgs.nodejs_22}" "$out" > $out/bin/meridian
      chmod +x $out/bin/meridian
    '';
  };

  ocx-pkg = pkgs.stdenv.mkDerivation {
    pname = "ocx";
    version = "2.0.4";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/ocx/-/ocx-2.0.4.tgz";
      hash = "sha256-3Jq+QJju8Iy2tEztc0JaChWFaj3TWmwQlsVdFvzOJWw=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      tar xzf $src --strip-components=1 -C $out
    '';
  };
  ocx = pkgs.writeShellScriptBin "ocx" ''
    exec ${pkgs.bun}/bin/bun --no-env-file "${ocx-pkg}/dist/index.js" "$@"
  '';

  # Machines that use baseline bun and cannot build context7-mcp due to FOD
  baseline-bun-machines = [ "rig" "clawsiecats" ];

  # Anti-detection init script for headless mode
  playwright-init-script = pkgs.writeText "playwright-init.js" ''
    // Override navigator.webdriver
    Object.defineProperty(navigator, 'webdriver', {
      get: () => false,
    });

    // Override chrome detection
    window.chrome = {
      runtime: {},
    };

    // Override permissions
    const originalQuery = window.navigator.permissions.query;
    window.navigator.permissions.query = (parameters) => (
      parameters.name === 'notifications' ?
        Promise.resolve({ state: Notification.permission }) :
        originalQuery(parameters)
    );
  '';

  # Wrapper script that copies user-data-dir before launching Playwright MCP server.
  # This allows multiple OpenCode instances to run parallel browser agents with
  # same logged-in session state, avoiding user-data-dir locking conflicts.
  playwright-mcp-wrapper = pkgs.writeShellScript "playwright-mcp-wrapper" ''
    # Cleanup any orphan chromium-playwright-* temp profiles that are not in use
    for dir in /tmp/chromium-playwright-*; do
      if [ -d "$dir" ]; then
        dir_name=$(basename "$dir")
        echo "=== DEBUG: Checking directory: $dir_name ===" >&2

        # Check if any playwright process is using this specific user-data-dir
        if ${pkgs.procps}/bin/pgrep -f "user-data-dir.*$dir_name" >/dev/null 2>&1; then
          continue
        fi

        # Check if any process has the lock file open (if it exists)
        if [ -f "$dir/.lock" ] && ${pkgs.psmisc}/bin/fuser "$dir/.lock" >/dev/null 2>&1; then
          continue
        fi

        # If we get here, the profile is not in use - remove it
        rm -rf "$dir"
      fi
    done

    # Create unique temp directory using mktemp for better uniqueness
    TEMP_PROFILE=$(mktemp -d -t chromium-playwright-XXXXXX)

    # Copy original chromium profile to temp directory
    ${pkgs.rsync}/bin/rsync -a --quiet \
      "${config.home.homeDirectory}/.config/chromium/" \
      "$TEMP_PROFILE/"

    # Create lock file and keep file descriptor open for entire process lifetime
    # This ensures SIGKILL-safe cleanup detection
    exec 3>"$TEMP_PROFILE/.lock"

    # Cleanup function to remove temp profile on graceful exit
    cleanup() {
      # Close file descriptor before removing directory
      exec 3>&-
      rm -rf "$TEMP_PROFILE"
    }
    # Ensure cleanup happens on normal exit, interrupt, or termination
    trap cleanup EXIT INT TERM SIGINT SIGTERM

    # Build command arguments
    ARGS=(
      --executable-path "${pkgs.chromium}/bin/chromium"
      --user-data-dir "$TEMP_PROFILE"
      --ignore-https-errors
      --caps vision
      # Below don't work
      # --isolated
    )

    # Add headless and anti-detection options only when DISPLAY is not set
    if [ -z "$DISPLAY" ]; then
      ARGS+=(
        --headless
        --viewport-size "1271x936"
        --init-script "${playwright-init-script}"
      )
    fi
    # --user-agent "Mozilla/5.0 AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36"
    # --no-sandbox

    # sleep 30 && cleanup &

    # Launch playwright MCP server with copied profile
    exec ${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp "''${ARGS[@]}" "$@"
  '';
in
{
  imports = [ inputs.meridian.homeManagerModules.default ];

  services.meridian = {
    enable = true;
    package = meridian-patched;
    settings = {
      port = 3456;
      host = "127.0.0.1";
      defaultAgent = "opencode";
      sonnetModel = "claude-sonnet-4-6";
    };
    environment = {
      MERIDIAN_BETA_POLICY = "strip-all";
      MERIDIAN_STRIP_CACHE_CONTROL = "1";
      MERIDIAN_IDLE_TIMEOUT_SECONDS = "300";
    };
  };

  # Don't start meridian on boot — opencode wrapper starts it on demand
  systemd.user.services.meridian.Install.WantedBy = lib.mkForce [];

  home.sessionVariables = {
    ANTHROPIC_API_KEY = "x";
    ANTHROPIC_BASE_URL = "http://127.0.0.1:3456";
  };

  sops.secrets = {
    "z_ai_api.key" = lib.mkIf hasZaiApiKey {};
    "github.token" = {};
    "karakeep_api.address" = {};
    "karakeep_api.key" = {};
    "paperless.url" = {};
    "paperless_api.key" = {};
    "paperless_public.url" = {};
    "home_assistant.long_lived_token" = {};
    "opencode_api.key" = {};
    "openai_api.key" = {};
    "xiaomi_api.key" = {};
    "github_copilot.refresh" = {};
    "github_copilot.access" = {};
  };

  home.packages = [
    pkgs.bun
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ocx
    mcp-servers-nix.playwright-mcp
    mcp-servers-nix.context7-mcp
    # inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.vibe-kanban
    pkgs.rsync
    pkgs.psmisc
    pkgs.procps
    pkgs.nodejs_24
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk
  ] ++ lib.optionals ((lib.attrByPath ["environment" "sessionVariables" "WAYLAND_DISPLAY"] "" osConfig) != "") [
    # Required to play notification sounds with opencode-notifier.
    pkgs.pulseaudio
  ];
  programs.chromium = {
    enable = true;
    package = pkgs.chromium;
  };
  programs.opencode = {
    enable = true;
    package =
      let
        real-opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      in
      pkgs.symlinkJoin {
        name = "opencode-with-meridian";
        paths = [ real-opencode ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencode \
            --run 'systemctl --user start meridian'
        '';
      };
    skills = lib.optionalAttrs isNiriEnabled {
      "niri-screenshot" = ''
        ---
        name: niri-screenshot
        description: Take screenshots using niri compositor
        ---

        ## What I do

        - Capture the focused screen, window, or selected region
        - Save to a specified path via `--path` flag

        ## Commands

        - `niri msg action screenshot --path /tmp/screenshot.png` - Interactive region selection
        - `niri msg action screenshot-screen --path /tmp/screenshot.png` - Capture focused screen
        - `niri msg action screenshot-window --path /tmp/screenshot.png` - Capture focused window

        ## When to use me

        Use this when you require taking screenshot or need to capture what's on the screen.
        Ask clarifying questions if it's unclear whether to capture the full screen, window, or region.
      '';
    };
    context = ''
      - NEVER include your own emotes in your responses.
      - You're working with NixOS. Use `nix-shell -p` or comma (e.g. `, cowsay hi`)
        to run any tools not currently available on the system.
      - Unless stated otherwise, Use `sudo nixos-rebuild switch --flake </path/to/>#<flake>`
        to rebuild NixOS configuration.
    '';
      # - Use `rg` (ripgrep) instead of `grep` and `fd` (fd-find) instead of `find` for searching
      #   through code and files.
      # - Terse like caveman. Technical substance exact. Only fluff die.
      #   Drop: articles, filler (just/really/basically), pleasantries, hedging.
      #   Fragments OK. Short synonyms. Code unchanged.
      #   Pattern: [thing] [action] [reason]. [next step].
      #   ACTIVE EVERY RESPONSE. No revert after many turns. No filler drift.
      #   Code/commits/PRs: normal. Off: "stop caveman" / "normal mode".
    commands = {
      rebuild-switch = ''
        Rebuild and switch to NixOS flake configuration you're currently working on.
        Usage: /rebuild-switch
      '';
      caveman = ''
        Activate caveman ultra-compressed communication mode.
        Supports intensity levels: lite, full (default), ultra.
        Usage: /caveman [level]
      '';
      karpathy-guidelines = ''
        Load Andrej Karpathy behavioral guidelines skill.
        Usage: /karpathy-guidelines
      '';
    };
    settings = {
      # NOTE: This requires `programs.mcp` to be configured. For now, I've defined
      # MCP servers below in opencode itself so this isn't required.
      # enableMcpIntegration = true;
      #
      # Provider name and model name schema in opencode can be found here:
      # $ curl -s https://opencode.ai/zen/v1/models | jq

      model = "zai-coding-plan/glm-4.7";
      small_model = "opencode/gpt-5-nano";
      provider = {
        "opencode".options.timeout = false;
        "anthropic" = {
          options = {
            timeout = false;
            baseURL = "http://127.0.0.1:3456";
          };
        };
        "zai-coding-plan" = {
          options.timeout = false;
          models = {
            "glm-4.7" = {
              name = "GLM 4.7";
              options = {
                reasoningEffort = "high";
                reasoningSummary = "auto";
                textVerbosity = "low";
              };
            };
          };
        };
        ollama = {
          npm = "ai-sdk-ollama";
          models = {
            "qwen3:8b" = {
              name = "qwen3:8b";
              tools = true;
            };
            "gemma4:latest" = {
              name = "gemma4:latest";
              tools = true;
            };
            "gemma4:e2b" = {
              name = "gemma4:e2b";
              tools = true;
            };
          };
          options = {
            baseURL = "http://rig.lion-zebra.ts.net:11434";
          };
        };
      };

      permission = {
        external_directory = "allow";
      };

      mcp = {
        zai-web-search = lib.mkIf hasZaiApiKey {
          enabled = true;
          type = "remote";
          url = "https://api.z.ai/api/mcp/web_search_prime/mcp";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."z_ai_api.key".path}}";
          };
        };
        zai-web-reader = lib.mkIf hasZaiApiKey {
          enabled = true;
          type = "remote";
          url = "https://api.z.ai/api/mcp/web_reader/mcp";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."z_ai_api.key".path}}";
          };
        };
        zai-zread = lib.mkIf hasZaiApiKey {
          enabled = true;
          type = "remote";
          url = "https://api.z.ai/api/mcp/zread/mcp";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."z_ai_api.key".path}}";
          };
        };
        zai-vision = lib.mkIf hasZaiApiKey {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.nodejs_24}/bin/node"
            "${pkgs.nodejs_24}/bin/npx"
            "-y"
            "@z_ai/mcp-server"
          ];
          environment = {
            # PATH = "${pkgs.bash}/bin:${pkgs.nodejs_24}/bin";
            PATH = pkgs.lib.makeBinPath [
              pkgs.nodejs_24
              pkgs.bash
            ];
            Z_AI_MODE = "ZAI";
            Z_AI_API_KEY = "{file:${config.sops.secrets."z_ai_api.key".path}}";
          };
        };
        kindly-web-search = lib.mkIf (!hasZaiApiKey) {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.uv}/bin/uvx"
            "--from"
            "git+https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server"
            "kindly-web-search-mcp-server"
            "start-mcp-server"
          ];
          environment = {
            PATH = pkgs.lib.makeBinPath [
              pkgs.uv
              pkgs.git
              pkgs.coreutils
              pkgs.python3
            ];
            GITHUB_TOKEN = "{file:${config.sops.secrets."github.token".path}}";
            SEARXNG_BASE_URL = "http://pilab.lion-zebra.ts.net:6040/";
          };
        };
        # NOTE: context7-mcp is automatically disabled on machines with baseline bun
        # (rig, clawsiecats) because it uses buildBunPackage which creates a
        # Fixed-Output Derivation (FOD) for dependencies. The FOD is cached and
        # cannot be overridden to use baseline bun without changing the output hash.
        #
        # To enable context7 on these machines, you would need to:
        # 1. Build bun baseline manually and install it outside Nix, OR
        # 2. Fork mcp-servers-nix and modify context7 package to support baseline bun
        context7 = lib.mkIf (!builtins.elem hostName baseline-bun-machines) {
          enabled = true;
          type = "local";
          command = ["${mcp-servers-nix.context7-mcp}/bin/context7-mcp"];
        };
        playwright = {
          enabled = true;
          type = "local";
          # Use wrapper script instead of direct command to enable parallel agents
          # with copied user-data-dir (preserves login sessions without conflicts)
          command = [
            "${playwright-mcp-wrapper}"
            # Additional args can be passed here and will be forwarded via "$@"
            # TODO: Use headless if no DISPLAY-like environment variable is set.
            # "--headless"

            # TODO: See if it's possible to declartively install extension.
            # https://github.com/microsoft/playwright-mcp/blob/main/extension/README.md
            # "--extension"
          ];
          # environment = {
          #   PLAYWRIGHT_MCP_EXTENSION_TOKEN = "PLAYWRIGHT_MCP_EXTENSION_TOKEN_HERE";
          # };
        };
        nixos = {
          enabled = true;
          type = "local";
          command = ["${pkgs.mcp-nixos}/bin/mcp-nixos"];
        };
        github = {
          enabled = true;
          type = "remote";
          url = "https://api.githubcopilot.com/mcp/";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."github.token".path}}";
          };
        };
        karakeep = {
          enabled = true;
          type = "local";
          timeout = 60000;  # 60 seconds to compensate for lazy load.
          command = [
            "${pkgs.nodejs_24}/bin/node"
            "${pkgs.nodejs_24}/bin/npx"
            "-y"
            "@karakeep/mcp"
          ];
          environment = {
            # PATH = "${pkgs.bash}/bin:${pkgs.nodejs_24}/bin";
            PATH = pkgs.lib.makeBinPath [
              pkgs.nodejs_24
              pkgs.bash
            ];
            KARAKEEP_API_ADDR = "{file:${config.sops.secrets."karakeep_api.address".path}}";
            KARAKEEP_API_KEY = "{file:${config.sops.secrets."karakeep_api.key".path}}";
          };
        };
        paperless = {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.nodejs_24}/bin/node"
            "${pkgs.nodejs_24}/bin/npx"
            "-y"
            "@baruchiro/paperless-mcp@latest"
          ];
          environment = {
            PATH = pkgs.lib.makeBinPath [
              pkgs.nodejs_24
              pkgs.bash
            ];
            PAPERLESS_URL = "{file:${config.sops.secrets."paperless.url".path}}";
            PAPERLESS_API_KEY = "{file:${config.sops.secrets."paperless_api.key".path}}";
            PAPERLESS_PUBLIC_URL = "{file:${config.sops.secrets."paperless_public.url".path}}";
          };
        };
        homeassistant = {
          enabled = true;
          type = "remote";
          url = "http://pilab.lion-zebra.ts.net:8123/mcp_server/sse";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."home_assistant.long_lived_token".path}}";
          };
        };
        # gmail = {
        #   enabled = true;
        #   type = "local";
        #   command = [
        #     "${pkgs.nodejs_24}/bin/node"
        #     "${pkgs.nodejs_24}/bin/npx"
        #     "-y"
        #     "@gongrzhe/server-gmail-autoauth-mcp"
        #   ];
        #   environment = {
        #     PATH = "${pkgs.bash}/bin:${pkgs.nodejs_24}/bin";
        #     PATH = pkgs.lib.makeBinPath [
        #       pkgs.nodejs_24
        #       pkgs.bash
        #     ];
        #     GMAIL_CREDENTIALS_PATH = pkgs.writeText "gmail-credentials.json" ''
        #     {
        #       "access_token": "access_token",
        #       "refresh_token": "refresh_token",
        #       "scope": "https://www.googleapis.com/auth/gmail.settings.basic https://www.googleapis.com/auth/gmail.modify",
        #       "token_type": "Bearer",
        #       "expiry_date": 1763058215799
        #     }
        #     '';
        #   };
        # };
      };

      agent = {
        debug = {
          mode = "primary";
          description = "Code Debugging Agent";
          prompt = ''
            # Code Debugging Agent

            You are a senior software engineer specializing in code analysis and debugging.

            ## Guidelines
            - Skim through the codebase initially. Continue gaining a better understanding of the
              codebase as you progress.
            - Understand how the program runs through the various control flows defined.
            - Make changes to files if absolutely necessary only after discussing with the
              user in order to debug better, otherwise just provide suggestions without making any
              changes to files at all.
            - Suggest improvements for any issues found and do not make changes without approval.
            - Search on the Internet if you're not really 100% sure about something, especially
              regarding documentation that can change quickly over time. You can use nixos and
              context7 tool to search for documentation.
            - Always include references to Internet URLs that you referred to when basing
              something on them.
            - Make code changes to existing files first and avoid creating new files.
            - Be concise, cut to the point, and do not write documentation unless explicitly asked.
            - Take a step back and think the broader picture if you feel yourself stuck in a loop.
          '';
          tools = {
            write = true;
            edit = true;
            bash = true;
          };
          temperature = 0.35;
        };
        browser = {
          mode = "primary";
          description = "Browser Agent";
          prompt = ''
            # Browser Agent

            You are a professional software engineer who uses the playwright tool to interact
            with the Internet.

            ## Guidelines
            - Skip captchas.
            - Do not write ANY file on the local filesystem WHATSOEVER.
            - Close browser tabs opened by you after you're done with them.
            - Take a step back and think the broader picture if you feel yourself stuck in a loop.
          '';
          tools = {
            read = true;
            edit = false;
            zai-vision = true;

            write = false;
            bash = false;
            # gmail = false;
            webfetch = false;
            zai-web-search = false;
            zai-web-reader = false;
            zai-zread = false;
            # Avoid installing browsers during confusion since browsers can't be installed
            # in NixOS through the approach taken by this tool.
            playwright_browser_install = false;
          };
          temperature = 0.2;
        };
        sensei = {
          mode = "primary";
          description = "Sensei Agent";
          prompt = ''
            # Sensei Agent

            You are a professional software engineer who'll mentor the user.

            ## Guidelines
            - Provide the user with hints, suggestions, and guidance.
            - Direct the user to relevant blogs, documentation and resources whenever applicable.
            - Avoid offering and implementing direct solutions.
          '';
          tools = {
            read = true;
            bash = true;
            edit = false;
            write = false;
          };
          temperature = 0.3;
        };
        conversational = {
          mode = "primary";
          description = "Conversational Agent";
          prompt = ''
            # Conversational Agent

            Engage in meaningful and context-aware conversations with the user. Be rational.
          '';
          tools = {
            write = false;
            bash = false;
            playwright_browser_install = false;
          };
          temperature = 0.4;
        };
        mcpless = {
          mode = "primary";
          description = "MCP-less Agent (no MCP tools)";
          tools = {
            "*" = false;
          };
        };
      };

      plugin = [
        config.services.meridian.opencode.pluginPath
        "@mohak34/opencode-notifier"
        "@tarquinen/opencode-dcp"
      ];

      autoupdate = false;
    };

    tui = {
      # XXX: I like the `system` theme but it takes a while to load:
      # https://github.com/anomalyco/opencode/issues/14965#issuecomment-3973081161
      theme = "lucent-orng";
      scroll_speed = 5;
    };
  };

  home.file = lib.mkMerge [
    {
      ".config/rtk/config.toml".source = (pkgs.formats.toml {}).generate "rtk-config" {
        telemetry.enabled = false;
      };
    }
    (lib.mkIf ((lib.attrByPath ["environment" "sessionVariables" "WAYLAND_DISPLAY"] "" osConfig) != "") {
      ".config/opencode/opencode-notifier.json".text = builtins.toJSON {
        notification = true;
        sound = true;
        showIcon = true;
        notificationSystem = "osascript";
        events = {
          complete = {
            sound = true;
            notification = true;
          };
          error = {
            sound = true;
            notification = true;
          };
          question = {
            sound = true;
            notification = true;
          };
          permission = {
            sound = true;
            notification = true;
          };
          subagent_complete = {
            sound = false;
            notification = false;
          };
          user_cancelled = {
            sound = true;
            notification = false;
          };
        };
        messages = {
          permission = "Permission: {sessionTitle}";
          complete = "Complete: {sessionTitle}";
          subagent_complete = "Subagent complete: {sessionTitle}";
          error = "Error: {sessionTitle}";
          question = "Question: {sessionTitle}";
          user_cancelled = "User cancelled: {sessionTitle}";
        };
        showProjectName = true;
        showSessionTitle = true;
        suppressWhenFocused = false;
      };
    })
  ];

  home.activation.opencode-skills-caveman = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "${config.home.homeDirectory}/.agents/skills/caveman" ]; then
      PATH=${pkgs.lib.makeBinPath [pkgs.nodejs_24 pkgs.bash pkgs.coreutils pkgs.git]} \
        ${pkgs.nodejs_24}/bin/npx --yes skills add juliusbrussee/caveman -g -a opencode -y
    fi
  '';

  home.activation.opencode-skills-karpathy = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "${config.home.homeDirectory}/.agents/skills/karpathy-guidelines" ]; then
      PATH=${pkgs.lib.makeBinPath [pkgs.nodejs_24 pkgs.bash pkgs.coreutils pkgs.git]} \
        ${pkgs.nodejs_24}/bin/npx --yes skills add forrestchang/andrej-karpathy-skills -g -a opencode -y
    fi
  '';

  home.activation.opencode-plugin-rtk = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "${config.home.homeDirectory}/.config/opencode/plugins/rtk.ts" ]; then
      ${inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk}/bin/rtk init -g --opencode
    fi
  '';

home.activation.opencode-plugin-get-shit-done = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "${config.home.homeDirectory}/.config/opencode/get-shit-done" ]; then
      PATH=${pkgs.lib.makeBinPath [pkgs.nodejs_24 pkgs.bash pkgs.coreutils pkgs.gettext pkgs.findutils pkgs.gawk pkgs.gnused pkgs.util-linux]} ${pkgs.nodejs_24}/bin/npx get-shit-done-cc --opencode --global
    fi
  '';

  home.activation.opencode-worktree = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "${config.home.homeDirectory}/.config/opencode/plugins/worktree.ts" ]; then
      PATH=${pkgs.lib.makeBinPath [pkgs.bun pkgs.bash pkgs.coreutils pkgs.gettext pkgs.findutils pkgs.gawk pkgs.gnused pkgs.util-linux]} ${ocx}/bin/ocx init --cwd "${config.home.homeDirectory}" || true
      PATH=${pkgs.lib.makeBinPath [pkgs.bun pkgs.bash pkgs.coreutils pkgs.gettext pkgs.findutils pkgs.gawk pkgs.gnused pkgs.util-linux]} ${ocx}/bin/ocx add kdco/worktree --from https://registry.kdco.dev --cwd "${config.home.homeDirectory}"
    fi
  '';

  home.activation.opencode-auth = lib.hm.dag.entryAfter ["writeBoundary" "sops-nix"] ''
    AUTH_FILE="${config.home.homeDirectory}/.local/share/opencode/auth.json"
    NIXOS_JSON=$(${pkgs.coreutils}/bin/mktemp)

    ZAI_KEY=${if hasZaiApiKey then "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."z_ai_api.key".path})" else "\"\""}
    OPENCODE_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."opencode_api.key".path})
    OPENAI_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."openai_api.key".path})
    XIAOMI_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xiaomi_api.key".path})
    GH_REFRESH=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."github_copilot.refresh".path})
    GH_ACCESS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."github_copilot.access".path})

    ${pkgs.jq}/bin/jq -n \
      --arg zai_key "$ZAI_KEY" \
      --arg opencode_key "$OPENCODE_KEY" \
      --arg openai_key "$OPENAI_KEY" \
      --arg xiaomi_key "$XIAOMI_KEY" \
      --arg gh_refresh "$GH_REFRESH" \
      --arg gh_access "$GH_ACCESS" \
      '{
        "zai-coding-plan": { type: "api", key: $zai_key },
        "opencode": { type: "api", key: $opencode_key },
        "openai": { type: "api", key: $openai_key },
        "xiaomi": { type: "api", key: $xiaomi_key },
        "anthropic": { type: "api", key: "x" },
        "github-copilot": { type: "oauth", refresh: $gh_refresh, access: $gh_access, expires: 0 }
      }' > "$NIXOS_JSON"

    if [ -f "$AUTH_FILE" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$AUTH_FILE" "$NIXOS_JSON" > "$AUTH_FILE.tmp" \
        && mv "$AUTH_FILE.tmp" "$AUTH_FILE"
    else
      mkdir -p "$(${pkgs.coreutils}/bin/dirname "$AUTH_FILE")"
      cp "$NIXOS_JSON" "$AUTH_FILE"
    fi
    chmod 600 "$AUTH_FILE"
    rm -f "$NIXOS_JSON"
  '';
}
