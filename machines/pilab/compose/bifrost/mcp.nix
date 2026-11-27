# MCP servers behind Bifrost's /mcp gateway, so OpenCode and Hermes reach them
# through one endpoint. Names can't contain "-" (Bifrost's tool separator).
# Stdio servers run inside the Bifrost container (it mounts /nix/store and
# commandDir) from these wrappers; Bifrost hands its whole environment, secrets
# included, to the processes it spawns, so each wrapper starts its server with
# `env -i` and only that server's own variables.
{ pkgs, lib, inputs }:

let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  # Snapshots and console logs go to the container's /tmp, not the data dir.
  playwright-mcp = "${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp --output-dir /tmp/playwright-mcp";
  # Writable and persistent (dataDir): npm/uv caches and ssh known_hosts.
  home = "/app/data/mcp";

  # `vars` are copied from Bifrost's environment (stack.env) by name.
  wrap = name: { path ? [ ], vars ? [ ], env ? { }, setup ? "" }: command:
    pkgs.writeShellScript "bifrost-mcp-${name}" ''
      PATH=${pkgs.coreutils}/bin # the image has no system tools
      mkdir -p ${home}
      ${setup}
      exec ${pkgs.coreutils}/bin/env -i HOME=${home} \
        PATH=${lib.makeBinPath (path ++ [ pkgs.coreutils ])} \
        SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        ${lib.concatMapStrings (v: ''${v}="''$${v}" '') vars}\
        ${lib.concatStrings (lib.mapAttrsToList (k: v: "${k}=${lib.escapeShellArg v} ") env)}\
        ${command}
    '';

  # Lightpanda's cloud Chrome over CDP, named "chromium" so nodriver finds it.
  cloud-cdp-chromium = pkgs.writeShellScriptBin "chromium" ''
    export CLOUD_CDP_WSS="wss://euwest.cloud.lightpanda.io/ws?token=$LIGHTPANDA_TOKEN&browser=chrome"
    exec ${pkgs.python3.withPackages (ps: [ ps.websockets ])}/bin/python3 \
      ${../../../../modules/home/cloud-cdp-proxy.py} "$@"
  '';

  # Playwright's --executable-path: CDP on fds 3/4, carried over ssh to
  # chromium-agent on alcove (machines/alcove/browser.nix), the same contract as
  # modules/home/opencode/playwright.nix. Seeded with mishy's profile; refresh it
  # with `sync-chromium-to-alcove mishy` on mishy.
  chromium-alcove = pkgs.writeShellScript "chromium-alcove-bifrost" ''
    exec ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 \
      -i ${home}/.ssh/alcove -o IdentitiesOnly=yes \
      ritiek@alcove.lion-zebra.ts.net \
      CHROMIUM_SEED=.cache/chromium-seed/mishy chromium-agent "''${@@Q}" \
      '3<&0 4>&1 </dev/null >&2' <&3 >&4
  '';

  # Bifrost never updates a stored stdio command, so clients get a fixed path
  # here, a symlink default.nix points at the current wrapper on each deploy.
  commandDir = "/run/bifrost-mcp";
  stdio = name: timeout: wrapper: { inherit name timeout wrapper; };
  stdioClient = s: {
    inherit (s) name;
    connection_type = "stdio";
    stdio_config = { command = "${commandDir}/${s.name}"; args = [ ]; envs = [ ]; };
    auth_type = "none";
    tools_to_execute = [ "*" ];
    tool_execution_timeout = s.timeout;
  };
  http = name: url: extra: {
    inherit name;
    connection_type = "http";
    connection_string = url;
    auth_type = "none";
    tools_to_execute = [ "*" ];
  } // extra;
  bearer = var: { auth_type = "headers"; headers.Authorization = "env.${var}"; };

  remote = [
    (http "github" "https://api.githubcopilot.com/mcp/" (bearer "GITHUB_AUTHORIZATION"))
    (http "homeassistant" "http://radrubble.lion-zebra.ts.net:8123/api/mcp" (bearer "HASS_AUTHORIZATION"))
    (http "context7" "https://mcp.context7.com/mcp" { })
    # Signed in once from the dashboard (MCP servers, Authorize).
    (http "indmoney" "https://mcp.indmoney.com/mcp" { auth_type = "oauth"; })
  ];

  local = [
    (stdio "nixos" 120 (wrap "nixos" { } "${pkgs.mcp-nixos}/bin/mcp-nixos"))
    (stdio "paperless" 120 (wrap "paperless" {
      vars = [ "PAPERLESS_URL" "PAPERLESS_API_KEY" "PAPERLESS_PUBLIC_URL" ];
    } (lib.getExe (pkgs.callPackage ./paperless-mcp.nix { }))))
    (stdio "open_design" 600 (wrap "open-design" { }
      "${pkgs.callPackage ../../../../modules/home/opencode/open-design-mcp.nix { }} --daemon-url http://127.0.0.1:7456"))
    (stdio "kindly_web_search" 600 (wrap "kindly-web-search" {
      path = [ pkgs.uv pkgs.git pkgs.python3 cloud-cdp-chromium ];
      vars = [ "GITHUB_TOKEN" "SEARXNG_BASE_URL" "LIGHTPANDA_TOKEN" ];
      env = {
        # The image has no system Python or loader for uv's downloaded ones.
        UV_PYTHON = "${pkgs.python3}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";
        KINDLY_BROWSER_EXECUTABLE_PATH = "${cloud-cdp-chromium}/bin/chromium";
        KINDLY_TOOL_TOTAL_TIMEOUT_SECONDS = "300";
        KINDLY_TOOL_TOTAL_TIMEOUT_MAX_SECONDS = "600";
        KINDLY_WEB_SEARCH_MAX_CONCURRENCY = "3";
      };
    } (lib.concatStringsSep " " [
      "${pkgs.uv}/bin/uvx --from"
      # Pinned: unpinned + --refresh ran upstream HEAD on every start.
      "git+https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server@72a3e059bbddc42436efa1575e0895a30a62c351"
      "kindly-web-search-mcp-server start-mcp-server"
    ])))
    (stdio "playwright_lightpanda" 300 (wrap "playwright-lightpanda" {
      vars = [ "PLAYWRIGHT_MCP_CDP_ENDPOINT" ];
      setup = ''PLAYWRIGHT_MCP_CDP_ENDPOINT="wss://euwest.cloud.lightpanda.io/ws?token=$LIGHTPANDA_TOKEN&browser=chrome"'';
    } "${playwright-mcp} --caps vision"))
    (stdio "playwright_alcove" 300 (wrap "playwright-alcove" {
      path = [ pkgs.openssh ];
      env.PLAYWRIGHT_MCP_HEADLESS = "false"; # render in alcove's sway, on the GPU
      # stack.env holds the key base64-encoded (dotenv is single-line).
      setup = ''
        mkdir -p ${home}/.ssh
        printf '%s' "$ALCOVE_SSH_KEY_B64" | ${pkgs.coreutils}/bin/base64 -d > ${home}/.ssh/alcove
        chmod 600 ${home}/.ssh/alcove
      '';
    } "${playwright-mcp} --caps vision --executable-path ${chromium-alcove}"))
  ];
in
{
  inherit commandDir;
  clients = remote ++ map stdioClient local;
  wrappers = lib.listToAttrs (map (s: lib.nameValuePair s.name s.wrapper) local);
}
