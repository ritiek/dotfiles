{ config, pkgs, inputs, lib, hostName, ... }:
let
  # Image/installer variants (different hostName, same secrets) reuse their
  # base host's secrets file rather than a nonexistent per-variant directory.
  baseHost =
    if hostName == "mishy-usb" then "mishy"
    else if hostName == "pilab-sd" || hostName == "pilab-minimal-sd" then "pilab"
    else hostName;
  secretsFile = ./../../machines/${baseHost}/home/${config.home.username}/secrets.yaml;
  secretsContent = builtins.readFile secretsFile;
  hasZaiApiKey = lib.strings.hasInfix "z_ai_api.key:" secretsContent;

  # Shared auth generator — used by both home.activation (interactive hm switch)
  # and systemd --user service (boot: runs after sops-nix.service decrypts secrets).
  pi-auth-generator = pkgs.writeShellScript "pi-auth-generator" ''
    set -euo pipefail

    AUTH_FILE="${config.home.homeDirectory}/.pi/agent/auth.json"
    NIXOS_JSON=$(${pkgs.coreutils}/bin/mktemp)

    # Guard: sops secrets may not be available at boot (systemd --user not running yet)
    if [ ! -f "${config.sops.secrets."opencode_api.key".path}" ]; then
      echo "pi-auth: sops secrets not yet decrypted by sops-nix, skipping"
      rm -f "$NIXOS_JSON"
      exit 0
    fi

    OPENCODE_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."opencode_api.key".path})
    OPENAI_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."openai_api.key".path})
    GH_REFRESH=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."github_copilot.refresh".path})
    GH_ACCESS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."github_copilot.access".path})
    ${lib.optionalString hasZaiApiKey ''
    ZAI_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."z_ai_api.key".path})
    ''}

    ${if hasZaiApiKey then ''
    ${pkgs.jq}/bin/jq -n \
      --arg opencode_key "$OPENCODE_KEY" \
      --arg openai_key "$OPENAI_KEY" \
      --arg gh_refresh "$GH_REFRESH" \
      --arg gh_access "$GH_ACCESS" \
      --arg zai_key "$ZAI_KEY" \
      '{
        "opencode": { type: "api_key", key: $opencode_key },
        "openai": { type: "api_key", key: $openai_key },
        "github-copilot": { type: "oauth", refresh: $gh_refresh, access: $gh_access, expires: 0 },
        "zai": { type: "api_key", key: $zai_key }
      }' > "$NIXOS_JSON"
    '' else ''
    ${pkgs.jq}/bin/jq -n \
      --arg opencode_key "$OPENCODE_KEY" \
      --arg openai_key "$OPENAI_KEY" \
      --arg gh_refresh "$GH_REFRESH" \
      --arg gh_access "$GH_ACCESS" \
      '{
        "opencode": { type: "api_key", key: $opencode_key },
        "openai": { type: "api_key", key: $openai_key },
        "github-copilot": { type: "oauth", refresh: $gh_refresh, access: $gh_access, expires: 0 }
      }' > "$NIXOS_JSON"
    ''}

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
in
{
  sops.secrets = {
    "opencode_api.key" = {};
    "openai_api.key" = {};
    "github_copilot.refresh" = {};
    "github_copilot.access" = {};
  } // lib.optionalAttrs hasZaiApiKey {
    "z_ai_api.key" = {};
  };

  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ];

  home.file.".pi/agent/settings.json".text = builtins.toJSON ({
    defaultProvider = "anthropic";
    defaultModel = "claude-sonnet-4-20250514";
    defaultThinkingLevel = "medium";
    theme = "dark";
    enableInstallTelemetry = false;
    compaction = {
      enabled = true;
      reserveTokens = 16384;
      keepRecentTokens = 20000;
    };
    retry = {
      enabled = true;
      maxRetries = 3;
      provider = {
        timeoutMs = 3600000;
        maxRetries = 0;
      };
    };
  });

  home.activation.pi-auth = lib.hm.dag.entryAfter ["writeBoundary" "sops-nix"] ''
    ${pi-auth-generator}
  '';

  systemd.user.services.pi-auth = {
    Unit = {
      Description = "Pi agent auth setup (after sops-nix decrypts secrets)";
      After = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pi-auth-generator}";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
