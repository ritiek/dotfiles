{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ];

  # Credentials are managed by pi itself (`/login`), stored in ~/.pi/agent/auth.json.

  # Minimal MCP set: no-secret local servers only, and no playwright for now.
  # pi connects to every enabled server at startup; try pi-mcp-adapter if this grows.
  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    mcpServers = {
      nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      context7.command = "${inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.context7-mcp}/bin/context7-mcp";
      codegraph = {
        command = "${inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codegraph}/bin/codegraph";
        args = [ "serve" "--mcp" ];
      };
      pdfvision = {
        command = "${inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pdfvision}/bin/pdfvision";
        args = [ "mcp" ];
      };
    };
  };

  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    defaultProvider = "github-copilot";
    defaultModel = "gpt-6-luna";
    defaultThinkingLevel = "medium";
    theme = "dark";
    enableInstallTelemetry = false;
    # Pi installs missing packages with npm on startup. Subscription login:
    # `/login anthropic`. Pinned so upgrades are deliberate.
    packages = [ "npm:@gotgenes/pi-anthropic-auth@3.4.4" ];
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
  };
}
