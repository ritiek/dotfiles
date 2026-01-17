{ osConfig, config, pkgs, inputs, lib, hostName, ... }:
let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

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
      --executable-path "${pkgs.unstable.chromium}/bin/chromium"
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
    exec ${mcp-servers-nix.playwright-mcp}/bin/mcp-server-playwright "''${ARGS[@]}" "$@"
  '';
in
{
  sops.secrets = {
    "z_ai_api.key" = {};
    "github.token" = {};
    "karakeep_api.address" = {};
    "karakeep_api.key" = {};
    "paperless.url" = {};
    "paperless_api.key" = {};
    "paperless_public.url" = {};
    "home_assistant.long_lived_token" = {};
  };

  home.packages = [
    mcp-servers-nix.playwright-mcp
    mcp-servers-nix.context7-mcp

    pkgs.rsync
    pkgs.psmisc
    pkgs.procps
  ];
  programs.chromium = {
    enable = true;
    package = pkgs.unstable.chromium;
  };
  programs.opencode = {
    enable = true;
    rules = ''
      NEVER include your own emotes in your responses.
    '';
    commands = {
      rebuild-switch = ''
        Rebuild and switch to NixOS flake configuration defined for current machine.
        Usage: /rebuild-switch
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
        "anthropic".options.timeout = false;
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
          npm = "@ai-sdk/openai-compatible";
          models = {
            "qwen3:8b" = {
              name = "Qwen 3 8B";
              tools = true;
              reasoning = true;
            };
          };
          options = {
            baseURL = "http://rig.lion-zebra.ts.net:11434/v1";
            reasoningEffort = "high";
            reasoningSummary = "auto";
            textVerbosity = "low";
            timeout = false;
          };
        };
      };

      mcp = {
        zai-websearch = {
          enabled = true;
          type = "remote";
          url = "https://api.z.ai/api/mcp/web_search_prime/mcp";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."z_ai_api.key".path}}";
          };
        };
        zai-vision = {
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
            - Do not write ANY file on the local filesystem whatsoever.
            - Close browser tabs opened by you after you're done with them.
            - Take a step back and think the broader picture if you feel yourself stuck in a loop.
          '';
          tools = {
            read = true;
            edit = true;
            zai-vision = true;

            write = false;
            bash = false;
            # gmail = false;
            webfetch = false;
            zai-websearch = false;
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
            - Do not spoon-feed the solution to the user. Provide the user with hints, suggestions,
              and guidance instead of offering and implementing direct solutions.
            - Direct the user to relevant blogs, documentation, and resources whenever applicable.
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
      };

      theme = "system";
      tui.scroll_speed = 5;
      autoupdate = false;
    };
  };
}
