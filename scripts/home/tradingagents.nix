{ pkgs, lib, config, ... }:

let
  rev = "7e9e7b83c7fcc18d941300b253c6ed24d985788d";
  installDir = "${config.home.homeDirectory}/.local/share/tradingagents";

  patchScript = pkgs.writeText "patch-tradingagents.py" ''
    import sys, os
    os.chdir(sys.argv[1])

    path = "tradingagents/llm_clients/anthropic_client.py"
    content = open(path).read()

    old = (
        "        if self.base_url:\n"
        "            llm_kwargs[\"base_url\"] = self.base_url\n"
    )
    new = (
        "        import os as _os\n"
        "        effective_base_url = self.base_url or _os.environ.get(\"ANTHROPIC_BASE_URL\")\n"
        "        if effective_base_url:\n"
        "            llm_kwargs[\"base_url\"] = effective_base_url\n"
    )

    assert old in content, f"Could not find base_url block to patch in {path}"
    content = content.replace(old, new)
    open(path, "w").write(content)
    print(f"Patched {path} with ANTHROPIC_BASE_URL support")

    path2 = "cli/utils.py"
    content2 = open(path2).read()

    old2 = '        ("Anthropic", "anthropic", "https://api.anthropic.com/"),'
    new2 = '        ("Anthropic", "anthropic", os.getenv("ANTHROPIC_BASE_URL", "https://api.anthropic.com/")),'

    assert old2 in content2, f"Could not find Anthropic provider entry in {path2}"
    content2 = "import os\n" + content2 if "import os" not in content2 else content2
    content2 = content2.replace(old2, new2)
    open(path2, "w").write(content2)
    print(f"Patched {path2} with ANTHROPIC_BASE_URL support")
  '';
in
{
  sops.secrets."tradingagents.env" = {};

  home.activation.tradingagents-setup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    INSTALL_DIR="${installDir}"
    REV="${rev}"
    SENTINEL="$INSTALL_DIR/.nix-rev"

    # Only reinstall if rev changed or install is missing
    if [ ! -f "$SENTINEL" ] || [ "$(${pkgs.coreutils}/bin/cat "$SENTINEL")" != "$REV" ]; then
      echo "Setting up TradingAgents @ $REV..."

      # Clone or reset repo
      if [ -d "$INSTALL_DIR/src/.git" ]; then
        ${pkgs.git}/bin/git -C "$INSTALL_DIR/src" fetch --quiet origin
        ${pkgs.git}/bin/git -C "$INSTALL_DIR/src" checkout --quiet "$REV"
        ${pkgs.git}/bin/git -C "$INSTALL_DIR/src" reset --hard "$REV"
      else
        ${pkgs.coreutils}/bin/mkdir -p "$INSTALL_DIR"
        ${pkgs.git}/bin/git clone --quiet \
          https://github.com/TauricResearch/TradingAgents.git \
          "$INSTALL_DIR/src"
        ${pkgs.git}/bin/git -C "$INSTALL_DIR/src" checkout --quiet "$REV"
      fi

      # Apply ANTHROPIC_BASE_URL patch
      ${pkgs.python3}/bin/python3 ${patchScript} "$INSTALL_DIR/src"

      # Create/recreate venv and install
      ${pkgs.uv}/bin/uv venv --python ${pkgs.python3}/bin/python3 \
        --clear \
        "$INSTALL_DIR/venv"
      ${pkgs.uv}/bin/uv pip install \
        --python "$INSTALL_DIR/venv/bin/python" \
        --no-cache \
        "$INSTALL_DIR/src"

      echo "$REV" > "$SENTINEL"
      echo "TradingAgents setup complete."
    fi
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "tradingagents" ''
      set -a
      source ${config.sops.secrets."tradingagents.env".path}
      set +a
      export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec "${installDir}/venv/bin/tradingagents" "$@"
    '')
  ];
}
