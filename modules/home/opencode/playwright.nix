{ config, pkgs, inputs, hostName, ... }:
let
  mcp-servers-nix = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  playwright-mcp = "${mcp-servers-nix.playwright-mcp}/bin/playwright-mcp";

  # On pilab (aarch64), pkgs.chromium has no binary cache for the pinned nixpkgs
  # and would build from source (~100GB scratch), exhausting the disk. The unstable
  # nixpkgs DOES have a cached aarch64 build, so use it there. Other hosts keep
  # pkgs.chromium unchanged.
  chromiumPackage = if hostName == "pilab" then pkgs.unstable.chromium else pkgs.chromium;

  # OpenCode's env carries an HTTP(S) proxy for LLM calls; it 407s browser/CDP traffic.
  noProxy = [ "${pkgs.coreutils}/bin/env" "-u" "HTTP_PROXY" "-u" "HTTPS_PROXY" "-u" "http_proxy" "-u" "https_proxy" ];

  ssh = "${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3";
  alcove = "ritiek@alcove.lion-zebra.ts.net";
  seed = ".cache/chromium-seed/${hostName}"; # on alcove, relative to ~

  # Pushes this machine's Chromium profile (logins, cookies) to alcove, where
  # chromium-agent (machines/alcove/browser.nix) copies it per browser instance.
  # Optional $1 picks the target seed host (default: this host), e.g.
  # `sync-chromium-to-alcove alcove` seeds playwright-alcove run on alcove itself.
  sync-chromium-to-alcove = pkgs.writeShellScriptBin "sync-chromium-to-alcove" ''
    src="$HOME/.config/chromium/Default/"
    [ -d "$src" ] || { echo "no $src, alcove will use a fresh profile" >&2; exit 0; }
    exec ${pkgs.rsync}/bin/rsync -az --delete --mkpath -e "${ssh}" \
      --exclude='Service Worker/' --exclude='GPUCache/' --exclude='Shared Dictionary/' \
      --exclude='File System/' --exclude='DawnWebGPUCache/' --exclude='DawnGraphiteCache/' \
      "$src" "${alcove}:.cache/chromium-seed/''${1:-${hostName}}/Default/"
  '';

  # Playwright's --executable-path: it speaks CDP on our fds 3 (in) and 4 (out);
  # ssh carries them as stdin/stdout and the remote shell maps them back to 3/4.
  chromium-alcove = pkgs.writeShellScript "chromium-alcove" ''
    ${sync-chromium-to-alcove}/bin/sync-chromium-to-alcove >&2 \
      || echo "profile sync failed, using alcove's last copy" >&2
    exec ${ssh} ${alcove} CHROMIUM_SEED=${seed} chromium-agent "''${@@Q}" \
      '3<&0 4>&1 </dev/null >&2' <&3 >&4
  '';

  server = command: { enabled = true; type = "local"; timeout = 120000; inherit command; };
in
{
  inherit chromiumPackage sync-chromium-to-alcove;

  chromiumProgram = {
    enable = true;
    package = chromiumPackage;
  };

  mcp = {
    # Local Chromium, fresh in-memory profile. Headless unless DISPLAY is set.
    playwright = server (noProxy ++ [
      playwright-mcp "--isolated" "--executable-path" "${chromiumPackage}/bin/chromium" "--caps" "vision"
    ]);

    # GPU Chromium in alcove's headless sway, seeded with this machine's profile.
    # Spawned on the first browser tool call, torn down when the MCP exits.
    playwright-alcove = server [
      playwright-mcp "--caps" "vision" "--executable-path"
      (if hostName == "alcove" then "/run/current-system/sw/bin/chromium-agent" else "${chromium-alcove}")
    ] // {
      environment.PLAYWRIGHT_MCP_HEADLESS = "false"; # render in sway, on the GPU
    };

    # Lightpanda cloud (real Chrome backend), no profile.
    playwright-lightpanda = server (noProxy ++ [ playwright-mcp "--caps" "vision" ]) // {
      environment.PLAYWRIGHT_MCP_CDP_ENDPOINT =
        "wss://euwest.cloud.lightpanda.io/ws?token={file:${config.sops.secrets."lightpanda_cdp.token".path}}&browser=chrome";
    };
  };
}
