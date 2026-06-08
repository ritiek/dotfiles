# Declarative overlay for hermes-agent PR #25995:
# https://github.com/NousResearch/hermes-agent/pull/25995
#
# Adds Matrix support for channel_skill_bindings, channel_prompts, and
# topic_as_prompt (room topic used as ephemeral system prompt).
#
# The patched files are full copies of gateway/config.py and
# gateway/platforms/matrix.py from the pinned hermes-agent venv, with the
# PR changes applied manually. Keep in sync when hermes-agent is updated.
#
# Loaded via a MetaPathFinder in sitecustomize.py (patches/claude-auth/)
# which intercepts imports of gateway.config and gateway.platforms.matrix
# and redirects them to this store path (via HERMES_GATEWAY_OVERLAY_DIR).
{ pkgs, ... }:

pkgs.runCommand "hermes-gateway-overlay-pr-25995" { } ''
  mkdir -p "$out/gateway/platforms"
  cp ${./config.py}  "$out/gateway/config.py"
  cp ${./matrix.py}  "$out/gateway/platforms/matrix.py"
''
