{ config, pkgs, inputs, lib, hostName, ... }:
let
  secretsFile =
    if hostName == "mishy-usb"
    then ./../../machines/mishy/home/${config.home.username}/secrets.yaml
    else ./../../machines/${hostName}/home/${config.home.username}/secrets.yaml;
  secretsContent = builtins.readFile secretsFile;
  hasZaiApiKey = lib.strings.hasInfix "z_ai_api.key:" secretsContent;
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
    AUTH_FILE="${config.home.homeDirectory}/.pi/agent/auth.json"
    NIXOS_JSON=$(${pkgs.coreutils}/bin/mktemp)

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
}
