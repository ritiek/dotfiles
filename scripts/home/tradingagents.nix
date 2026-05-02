{ pkgs, config, ... }:

{
  sops.secrets."tradingagents.env" = {};

  home.packages = [
    (pkgs.writeShellScriptBin "tradingagents" ''
      set -a
      source ${config.sops.secrets."tradingagents.env".path}
      set +a
      export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec ${config.home.homeDirectory}/code/TradingAgents/.venv/bin/tradingagents "$@"
    '')
  ];
}
