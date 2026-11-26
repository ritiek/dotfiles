{ osConfig, config, pkgs, inputs, lib, hostName, ... }:
let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  isNiriEnabled = builtins.any (pkg: pkg.pname or "" == "niri") config.home.packages;
  isWayland = (lib.attrByPath ["environment" "sessionVariables" "WAYLAND_DISPLAY"] "" osConfig) != "";

  playwright = import ./playwright.nix { inherit config pkgs inputs hostName; };

  secretsFile =
    if hostName == "mishy-usb"
    then ./../../../machines/mishy/home/${config.home.username}/secrets.yaml
    else ./../../../machines/${hostName}/home/${config.home.username}/secrets.yaml;
  secretsContent = builtins.readFile secretsFile;
  hasZaiApiKey = lib.strings.hasInfix "z_ai_api.key:" secretsContent;
  # Machines with this key register the `clawsiecats` provider (OpenCode's free models
  # through the ocfree middleman, machines/clawsiecats/services/ocfree) on activation.
  hasOcfreeKey = lib.strings.hasInfix "ocfree.key:" secretsContent;

  searxDomain = "clawsiecats.omg.lol";

  # Machines that use baseline bun and cannot build context7-mcp due to FOD
  baseline-bun-machines = [ "rig" "clawsiecats" ];

  # Cloud CDP proxy: tunnels nodriver's local CDP connections to Lightpanda cloud.
  # Real Chrome backend -- no lightpanda CDP quirk workarounds needed.
  # SearXNG is accessed directly by MCP code over HTTP (Tailscale), not through this proxy.
  cloud-cdp-proxy-py = pkgs.writeText "cloud-cdp-proxy.py" (builtins.readFile ../cloud-cdp-proxy.py);
  cloud-cdp-proxy-env = pkgs.python3.withPackages (ps: [ ps.websockets ]);
  # Named "chromium" so nodriver's find_chrome_executable() finds it in PATH.
  cloud-cdp-wrapper = pkgs.writeShellScriptBin "chromium" ''
    TOKEN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."lightpanda_cdp.token".path})
    export CLOUD_CDP_WSS="wss://euwest.cloud.lightpanda.io/ws?token=$TOKEN&browser=chrome"
    exec ${cloud-cdp-proxy-env}/bin/python3 ${cloud-cdp-proxy-py} "$@"
  '';

  # OpenDesign's `od mcp` stdio client, lifted out of the daemon image so it
  # runs on plain nodejs without a local Docker daemon. It is pure JS that
  # talks HTTP to the daemon on pilab; the native/media deps are dropped.
  # ponytail: pinned digest of 0.27.1, bump with nix-prefetch-docker together
  # with the pilab daemon's FROM tag (machines/pilab/compose/open-design).
  open-design-mcp = let
    image = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/nexu-io/od";
      imageDigest = "sha256:e60aec9fb7e07af9f11de58eff62a546c82421d3a24aa57a353b4c2808a1d85c";
      hash = {
        x86_64-linux = "sha256-cg4NhXsfl+s7v/N7wz2d8t2s36fpmOJCEuSFF8U/VG4=";
        aarch64-linux = "sha256-MnuTqGLXGLq+18VwZyPKCtEvTBEyTKx2T6TtvV0c3dA=";
      }.${pkgs.stdenv.hostPlatform.system};
      finalImageTag = "latest";
    };
    daemon = pkgs.runCommand "open-design-daemon" { nativeBuildInputs = [ pkgs.jq ]; } ''
      mkdir image $out
      tar -xf ${image} -C image
      for layer in $(jq -r '.[0].Layers[]' image/manifest.json); do
        tar -xf "image/$layer" -C $out --strip-components=3 app/apps/daemon 2>/dev/null || true
      done
      cd $out/node_modules/.pnpm
      rm -rf onnxruntime-node@* @ffmpeg-installer+* node-pty@* @img+sharp* esbuild@* @esbuild+*
      test -f $out/dist/cli.js
    '';
  in pkgs.writeShellScript "open-design-mcp" ''
    # od mcp exits after 30 min idle by default and opencode doesn't respawn it.
    export OD_MCP_STDIO_IDLE_EXIT_MS=0
    exec ${pkgs.nodejs_24}/bin/node ${daemon}/dist/cli.js mcp "$@"
  '';

  # Shared auth generator — used by both home.activation (interactive hm switch)
  # and systemd --user service (boot: runs after sops-nix.service decrypts secrets).
  # The guard at the top prevents failure at boot when systemd --user isn't running
  # and sops-nix secrets haven't been decrypted yet.
  opencode-auth-generator = pkgs.writeShellScript "opencode-auth-generator" (''
    set -euo pipefail

    AUTH_FILE="${config.home.homeDirectory}/.local/share/opencode/auth.json"
    NIXOS_JSON=$(${pkgs.coreutils}/bin/mktemp)

    # Guard: sops secrets may not be available at boot (systemd --user not running yet)
    if [ ! -f "${config.sops.secrets."opencode_api.key".path}" ]; then
      echo "opencode-auth: sops secrets not yet decrypted by sops-nix, skipping"
      rm -f "$NIXOS_JSON"
      exit 0
    fi

    # Unused: only opencode-go is written below.
    # ZAI_KEY=$(${pkgs.coreutils}/bin/cat <z_ai_api.key>)
    OPENCODE_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."opencode_api.key".path})
    # OPENAI_KEY=$(${pkgs.coreutils}/bin/cat <openai_api.key>)
    # XIAOMI_KEY=$(${pkgs.coreutils}/bin/cat <xiaomi_api.key>)
    # GH_REFRESH=$(${pkgs.coreutils}/bin/cat <github_copilot.refresh>)
    # GH_ACCESS=$(${pkgs.coreutils}/bin/cat <github_copilot.access>)

    ${pkgs.jq}/bin/jq -n \
      --arg opencode_key "$OPENCODE_KEY" \
      '{
        "opencode-go": { type: "api", key: $opencode_key }
      }' > "$NIXOS_JSON"

    # ${pkgs.jq}/bin/jq -n \
    #   --arg gh_refresh "$GH_REFRESH" \
    #   --arg gh_access "$GH_ACCESS" \
    #   '{
    #     "github-copilot": { type: "oauth", refresh: $gh_refresh, access: $gh_access, expires: 0 }
    #   }' > "$NIXOS_JSON"

    if [ -f "$AUTH_FILE" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$AUTH_FILE" "$NIXOS_JSON" > "$AUTH_FILE.tmp" \
        && mv "$AUTH_FILE.tmp" "$AUTH_FILE"
    else
      mkdir -p "$(${pkgs.coreutils}/bin/dirname "$AUTH_FILE")"
      cp "$NIXOS_JSON" "$AUTH_FILE"
    fi
    chmod 600 "$AUTH_FILE"
    rm -f "$NIXOS_JSON"
  '' + lib.optionalString hasOcfreeKey ''

    # Register the clawsiecats provider. OpenCode reads its well-known manifest, stores
    # the key, and from then on fetches the provider (live free models) on every start.
    # Only re-run when the key changes; a failed login (e.g. offline) retries next time.
    KEY_FILE=${config.sops.secrets."ocfree.key".path}
    MARK="${config.xdg.stateHome}/opencode/clawsiecats-key.sha256"
    SUM=$(${pkgs.coreutils}/bin/sha256sum < "$KEY_FILE" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
    if [ "$(${pkgs.coreutils}/bin/cat "$MARK" 2>/dev/null || true)" != "$SUM" ]; then
      # An empty config dir: the login needs the provider, not plugins or MCP servers.
      CFG=$(${pkgs.coreutils}/bin/mktemp -d)
      if (cd "$CFG" && XDG_CONFIG_HOME="$CFG" CLAWSIECATS_API_KEY=$(${pkgs.coreutils}/bin/cat "$KEY_FILE") \
          ${pkgs.coreutils}/bin/timeout 180 ${config.programs.opencode.package}/bin/opencode \
          auth login https://models.clawsiecats.omg.lol --method login --standalone < /dev/null); then
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$MARK")"
        echo "$SUM" > "$MARK"
      else
        echo "opencode-auth: clawsiecats login failed, retrying on the next activation"
      fi
      ${pkgs.coreutils}/bin/rm -rf "$CFG"
    fi
  '');

  # REA (github:morluto/rea). The npm tarball bundles its deps and the skill.
  rea = pkgs.fetchzip {
    url = "https://registry.npmjs.org/rea-agents/-/rea-agents-6.10.1.tgz";
    hash = "sha256-C4iPchmp1pFVe7eCRJZoatRPHe08yp5T09DsAAjJbPk=";
  };

  # Env var -> sops secret for opencode's built-in websearch providers.
  websearchSecrets = {
    EXA_API_KEY = "exa_api.key";
    FIRECRAWL_API_KEY = "firecrawl_api.key";
    PARALLEL_API_KEY = "parallel_api.key";
    TAVILY_API_KEY = "tavily_api.key";
    TINYFISH_API_KEY = "tinyfish_api.key";
  };

in
{
  sops.secrets = {
    "z_ai_api.key" = lib.mkIf hasZaiApiKey {};
    "ocfree.key" = lib.mkIf hasOcfreeKey {};
    "github.token" = {};
    "paperless.url" = {};
    "paperless_api.key" = {};
    "paperless_public.url" = {};
    "home_assistant.long_lived_token" = {};
    "opencode_api.key" = {};
    # Unused; only referenced by commented-out code in opencode-auth-generator.
    # "openai_api.key" = {};
    # "xiaomi_api.key" = {};
    # "github_copilot.refresh" = {};
    # "github_copilot.access" = {};
    "searx.url" = {};
    "lightpanda_cdp.token" = {};
  } // lib.mapAttrs' (_: s: lib.nameValuePair s {}) websearchSecrets;

  home.packages = [
    pkgs.uv
    pkgs.bun
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    mcp-servers-nix.playwright-mcp
    playwright.sync-chromium-to-alcove
    mcp-servers-nix.context7-mcp
    # inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.vibe-kanban
    pkgs.rsync
    pkgs.psmisc
    pkgs.procps
    pkgs.nodejs_24
    # shortcut: onig_sys needs pkg-config + oniguruma, missing on nixpkgs
    # 2026-11-22; drop once llm-agents adds them upstream.
    (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.toon.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.oniguruma ];
    }))
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pdfvision
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zat
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codegraph
  ] ++ lib.optionals isWayland [
    # Provides paplay for notification sounds.
    pkgs.pulseaudio
  ];
  programs.chromium = playwright.chromiumProgram;
  programs.opencode = {
    enable = true;
    # The package only ships `opencode2`; also expose it as `opencode` for
    # opencode.nvim and muscle memory.
    package = let
      oc2 = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
    in pkgs.symlinkJoin {
      name = "opencode-${oc2.version}";
      paths = [ oc2 ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      # Websearch providers only read their keys from env vars; export them
      # from the sops files at launch (skipped if not yet decrypted).
      postBuild = ''
        rm $out/bin/opencode2
        makeWrapper ${oc2}/bin/opencode2 $out/bin/opencode2 ${lib.concatStringsSep " " (lib.mapAttrsToList (var: s:
          "--run ${lib.escapeShellArg "[ -r ${config.sops.secrets.${s}.path} ] && export ${var}=$(cat ${config.sops.secrets.${s}.path})"}"
        ) websearchSecrets)}
        ln -s opencode2 $out/bin/opencode
      '';
      meta.mainProgram = "opencode";
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
    } // {
      "reverse-engineer-anything" = "${rea}/skills/reverse-engineer-anything";
    };
    context = ''
      - NEVER include your own emotes in your responses.
      - You're working with NixOS. Use `nix-shell -p` or comma (e.g. `, cowsay hi`)
        to run any tools not currently available on the system.
      - Unless stated otherwise, Use `sudo nixos-rebuild switch --flake </path/to/>#<flake>`
        to rebuild NixOS configuration and do NOT use `home-manager switch`. This applies only
        when rebuilding the machine you (opencode) are running on. To deploy to any other
        machine, use `deploy -s </path/to/>#<flake>`.
    ''
    + ''
      - If a request fails with a rate limit error or anything, retry it through the 3proxy
        HTTP proxy (port 8090, over Tailscale) on a machine outside your subnet, so the request
        leaves from a different public IP. 3proxy runs on pilab, keyberry, mishy, clawsiecats, m2,
        and maybe other machines as well
        (e.g. `curl -x http://<user>:<pass>@clawsiecats.lion-zebra.ts.net:8090 ...`).
        Credentials are in `/run/secrets/3proxy.users` on those machines (`user:CL:pass` format).
      - Use `rg` (ripgrep) instead of `grep` and `fd` (fd-find) instead of `find` for searching
        through code and files.
    '';
    commands = {
      rebuild-switch = ''
        Rebuild and switch to NixOS flake configuration you're currently working on.
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

      # model = "anthropic/claude-sonnet-5";
      # model = "opencode-go/gpt-5.6-luna";
      model = "github-copilot/gpt-6-luna";
      # small_model = "opencode-go/deepseek-v4-flash";
      small_model = "github-copilot/gpt-6-luna";
      default_agent = "build";
      # Rotate across all connected providers; falls over on HTTP 429.
      websearch.provider = "random";
      provider = {
        "opencode".options.timeout = false;
        "opencode-go".options.timeout = false;
        "anthropic" = {
          options = {
            timeout = false;
          };
        };
        # "zai-coding-plan" = {
        #   options.timeout = false;
        #   models = {
        #     "glm-4.7" = {
        #       name = "GLM 4.7";
        #       options = {
        #         reasoningEffort = "high";
        #         reasoningSummary = "auto";
        #         textVerbosity = "low";
        #       };
        #     };
        #   };
        # };
        ollama = {
          npm = "ai-sdk-ollama@3.8.2";
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

        llama-server = {
          npm = "@ai-sdk/openai-compatible@2.0.55";
          models = {
            "gemma:e4b" = {
              name = "gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf";
              tools = true;
            };
            "gemma4:12b" = {
              name = "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf";
              tools = true;
            };
          };
          options = {
            baseURL = "http://rig.lion-zebra.ts.net:8080";
          };
        };

        # Nous Portal Free plan via the hermes-nous-proxy on radrubble, which
        # attaches the OAuth login (the Free plan can't create API keys).
        # shortcut: the :free roster rotates, check portal.nousresearch.com/models.
        nous = {
          npm = "@ai-sdk/openai-compatible@2.0.55";
          name = "Nous Portal (free)";
          models = {
            "stepfun/step-3.7-flash:free" = {
              name = "Step 3.7 Flash (free)";
              tools = true;
            };
            "tencent/hy4-flash:free" = {
              name = "Hy4 Flash (free)";
              tools = true;
            };
            "upstage/solar-mini4:free" = {
              name = "Solar Mini 4 (free)";
              tools = true;
            };
          };
          options = {
            baseURL = "http://radrubble.lion-zebra.ts.net:8645/v1";
            apiKey = "unused";
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
            "@z_ai/mcp-server@0.1.4"
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
        # V2-native entries (no `enabled`): needed for an object `timeout`, which a
        # legacy `mcp.<name>` entry rejects. A legacy number also caps execution.
        servers = {
          inherit (playwright.mcp) playwright playwright-alcove playwright-lightpanda;
          kindly-web-search = lib.mkIf (!hasZaiApiKey) {
            type = "local";
            timeout = { startup = 60000; catalog = 60000; };
            command = [
              "${pkgs.uv}/bin/uvx"
              "--from"
              # Pinned: unpinned + --refresh ran upstream HEAD on every start.
              "git+https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server@72a3e059bbddc42436efa1575e0895a30a62c351"
              "kindly-web-search-mcp-server"
              "start-mcp-server"
            ];
            environment = {
              PATH = pkgs.lib.makeBinPath [
                pkgs.uv
                pkgs.git
                pkgs.coreutils
                pkgs.python3
                cloud-cdp-wrapper
              ];
              GITHUB_TOKEN = "{file:${config.sops.secrets."github.token".path}}";
              SEARXNG_BASE_URL = "{file:${config.sops.secrets."searx.url".path}}.${searxDomain}/";
              # XXX: Disable external browser in case of memory constraints as they cause
              # MCP timeouts in OpenCode.
              # KINDLY_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
              # KINDLY_BROWSER_EXECUTABLE_PATH = "${pkgs.writeShellScript "chromium-for-nodriver" ''
              #   exec ${pkgs.chromium}/bin/chromium \
              #     --no-sandbox \
              #     --disable-gpu \
              #     --disable-dev-shm-usage \
              #     "$@"
              # ''}";
              KINDLY_BROWSER_EXECUTABLE_PATH = "${cloud-cdp-wrapper}/bin/chromium";
              KINDLY_TOOL_TOTAL_TIMEOUT_SECONDS = "300";
              KINDLY_TOOL_TOTAL_TIMEOUT_MAX_SECONDS = "600";
              KINDLY_WEB_SEARCH_MAX_CONCURRENCY = "3";
              # KINDLY_DIAGNOSTICS = "1";
            };
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
        nixos = {
          enabled = true;
          type = "local";
          command = ["${pkgs.mcp-nixos}/bin/mcp-nixos"];
        };
        pdfvision = {
          enabled = true;
          type = "local";
          command = [
            "${inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pdfvision}/bin/pdfvision"
            "mcp"
          ];
        };
      } // lib.optionalAttrs (inputs.artcraft.packages ? ${pkgs.stdenv.hostPlatform.system}) {
        # Only on machines that declare the photocraft.token secret (mishy).
        photocraft = lib.mkIf (config.sops.secrets ? "photocraft.token") {
          enabled = true;
          type = "local";
          command = [
            "${inputs.artcraft.packages.${pkgs.stdenv.hostPlatform.system}.photocraft}/bin/photocraft-cli"
            "mcp"
            "--bridge"
            "127.0.0.1:9812"
            "--control-token-file"
            config.sops.secrets."photocraft.token".path
          ];
        };
      } // {
        github = {
          enabled = true;
          type = "remote";
          url = "https://api.githubcopilot.com/mcp/";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."github.token".path}}";
          };
        };
        paperless = {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.nodejs_24}/bin/node"
            "${pkgs.nodejs_24}/bin/npx"
            "-y"
            "@baruchiro/paperless-mcp@2.2.1"
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
          url = "http://radrubble.lion-zebra.ts.net:8123/api/mcp";
          headers = {
            Authorization = "Bearer {file:${config.sops.secrets."home_assistant.long_lived_token".path}}";
          };
        };
        codegraph = {
          enabled = true;
          type = "local";
          # Nix build: the npm package's prebuilt binary is generic-linux and
          # won't exec on NixOS.
          command = [
            "${inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codegraph}/bin/codegraph"
            "serve"
            "--mcp"
          ];
        };
        rea = {
          enabled = true;
          type = "local";
          command = [ "${pkgs.nodejs_24}/bin/node" "${rea}/scripts/rea.mjs" "mcp" ];
          environment = {
            PATH = lib.makeBinPath [ pkgs.nodejs_24 pkgs.openjdk25 pkgs.procps pkgs.bash ];
            GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";
            JAVA_HOME = "${pkgs.openjdk25}";
          };
        };
        indmoney = {
          enabled = true;
          type = "remote";
          url = "https://mcp.indmoney.com/mcp";
        };
        open-design = {
          enabled = true;
          type = "local";
          # The daemon runs on pilab with OD_DISABLE_API_AUTH=1 (Tailscale
          # is the trust boundary), so no token needs to be passed here.
          command = [
            "${open-design-mcp}"
            "--daemon-url"
            "http://pilab.lion-zebra.ts.net:7456"
          ];
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
        };
        browser = {
          mode = "primary";
          description = "Browser Agent";
          prompt = ''
            You are a professional software engineer who uses the playwright tool to interact
            with the Internet.

            ## Browsers
            Three playwright servers are available. Use `playwright-alcove` by default.
            - `playwright-alcove`: GPU Chromium on a remote machine (alcove), logged in with
              this machine's browser profile. First call takes 5-20 s to start.
            - `playwright`: local Chromium with a fresh profile (no logins). Use if
              `playwright-alcove` fails to start.
            - `playwright-lightpanda`: cloud Chrome with a fresh profile. Use if both above fail.

            ## Guidelines
            - Skip captchas.
            - Do not write ANY file on the local filesystem WHATSOEVER.
            - Close browser tabs opened by you after you're done with them.
            - Take a step back and think the broader picture if you feel yourself stuck in a loop.
          '';
          tools = {
            "*" = false;
            read = true;
            bash = false;
            skill = true;
            "codegraph*" = true;
            "pdfvision*" = true;
            "playwright*" = true;
            # Avoid installing browsers during confusion since browsers can't be installed
            # in NixOS through the approach taken by this tool.
            playwright_browser_install = false;
          };
        };
        sensei = {
          mode = "primary";
          description = "Sensei Agent";
          prompt = ''
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
        };
        conversational = {
          mode = "primary";
          description = "Conversational Agent";
          prompt = ''
            Engage in meaningful and context-aware conversations with the user. Be rational.
          '';
          tools = {
            write = false;
            bash = false;
            playwright_browser_install = false;
          };
        };
        # mcpless = {
        #   mode = "primary";
        #   description = "MCP-less Agent (no MCP tools)";
        #   tools = {
        #     "*" = false;
        #   };
        # };
        research = {
          mode = "subagent";
          description = "Research and Web-Search Agent";
          prompt = ''
            You are in research mode. Focus on:

            - Multiple web-searches using variety of search terms by playing the devil's advocate
              to challenge assumptions and gather perspective from ALL angles.
            - Most relevant sources AFTER explicitly finding out today's date and time using
              `homeassistant_llm__GetDateTime` tool or (if that is unavailable) from `https://time.now/developer/api/ip`
              JSON API endpoint.
            - Concise, structured information and strip raw data dumps.
          '';
          tools = {
            "*" = false;
            # Code Mode: MCP tools sit behind `execute` instead of being listed
            # in full on every request. Nested calls still obey this allowlist.
            execute = true;
            homeassistant_llm__GetDateTime = true;
            read = true;
            webfetch = true;
            "kindly-web-search*" = true;
            "github*" = true;
            "context7*" = true;
            "nixos*" = true;
            "indmoney*" = true;
            "pdfvision*" = true;
            "codegraph*" = true;
          };
        };
        critic = {
          mode = "subagent";
          description = "Builds the strongest evidence-backed case against a proposed plan. Pass the goal and the full plan verbatim.";
          prompt = ''
            You are reviewing a proposed plan, not writing one.

            - Re-read the relevant code yourself; do not trust the plan's description of it.
            - Look for: wrong assumptions, missed callers/config/tests, data-loss or security
              risk, a simpler alternative, and scope creep.
            - Every objection needs evidence (file:line, doc URL, or a concrete failing case)
              and a severity (blocker / should-fix / nit). Drop anything you can't back up.
            - "No substantive objections" is a valid and good outcome.
            - End with a verdict: proceed / revise / rethink.
          '';
          # Read-only via tool allowlist: cli.json autoaccept would approve "ask" permissions.
          tools = {
            "*" = false;
            execute = true; # Code Mode; see research.
            read = true;
            glob = true;
            grep = true;
            webfetch = true;
            "codegraph*" = true;
            "context7*" = true;
            "nixos*" = true;
          };
        };
      };

      plugin = [
        # The V1 Anthropic login doesn't carry over and gets billed as extra
        # usage (429). Once per machine, import the Claude Code login and drop
        # the old one:
        #   opencode auth login anthropic --method claude-code
        #   opencode auth logout anthropic OAuth
        "opencode-claude-auth@3.0.0"
        # "@tarquinen/opencode-dcp@3.2.0"
        "@dietrichgebert/ponytail@5.3.3"
        # /edit-prefix: edit the system prompt and history the model sees in $EDITOR.
        "${inputs.opencode-prefix-editor.packages.${pkgs.stdenv.hostPlatform.system}.default}"
        "opencode-handoff@0.7.0"
      ];

      autoupdate = false;
    };
  };

  # opencode2 reads these from ~/.config/opencode/cli.json, which the TUI also
  # writes, so merge into it instead of symlinking a read-only file.
  home.activation.opencode-cli-settings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    f="${config.home.homeDirectory}/.config/opencode/cli.json"
    mkdir -p "$(dirname "$f")"
    # -s: jq prints nothing for an empty file, which would leave it empty forever.
    [ -s "$f" ] || echo '{}' > "$f"
    tmp=$(mktemp)
    ${pkgs.jq}/bin/jq '. * $s' --argjson s ${lib.escapeShellArg (builtins.toJSON {
      prompt.image_preview = true;
      session.image_preview = true;
      session.permissions = "autoaccept";
      session.tps = true;
      theme.name = "cursor";
      scroll.speed = 5;
      session.thinking = "show";
      session.scrollbar = true;
      session.verbosity = "high";
      animations = true;
      tabs = {
        mode = "on";
        layout = "vertical";
        indicators = "numbers";
      };
      # Each value keeps the upstream defaults and adds the alt binding.
      keybinds = {
        "session.tab.next" = "ctrl+tab,alt+down,alt+j";
        "session.tab.previous" = "ctrl+shift+tab,alt+up,alt+k";
        "session.tab.select.10" = "<leader>0,ctrl+0,alt+0";
      } // lib.genAttrs (map (n: "session.tab.select.${toString n}") (lib.range 1 9))
        (k: let n = lib.last (lib.splitString "." k); in "<leader>${n},ctrl+${n},alt+${n}");
      attention.notifications = true;
      attention.sound = true;
      debug.devtools = true;
      debug.timing = false;
      debug.turn_tokens = "verbose";
      experimental.new-designs = true;
    })} "$f" > "$tmp" && install -m 600 "$tmp" "$f"
    rm -f "$tmp"
  '';

  home.file = lib.mkMerge [
    {
      # ".config/opencode/dcp.jsonc".text = builtins.toJSON {
      #   "$schema" = "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";
      #   compress = {
      #     minContextLimit = 75000;
      #     maxContextLimit = 150000;
      #   };
      # };
    }
  ];

  home.activation.opencode-auth = lib.hm.dag.entryAfter ["writeBoundary" "sops-nix"] ''
    ${opencode-auth-generator}
  '';

  systemd.user.services = {
    opencode-auth = {
      Unit = {
        Description = "OpenCode auth setup (after sops-nix decrypts secrets)";
        After = [ "sops-nix.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${opencode-auth-generator}";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
