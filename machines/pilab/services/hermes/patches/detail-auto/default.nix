# Patch for hermes-agent: add detail: "auto" to image_url blocks.
# Without it, providers tokenize images at full resolution — 25-60x more image
# tokens than necessary.  https://github.com/NousResearch/hermes-agent/issues/13065
#
# Patches (one line each):
#   - agent/image_routing.py:  build_native_content_parts() — 2 injection points
#   - tools/computer_use/tool.py: screenshot capture — 1 injection point
#   - tools/vision_tools.py: _build_native_vision_tool_result() — 1 injection point
#     (this is the local-image-file path: vision_analyze base64-embeds the file
#      and hands the pixels to the main model natively)
#
# Loaded via MetaPathFinder in sitecustomize.py (patches/claude-auth/), keyed off
# the HERMES_DETAIL_AUTO_OVERLAY_DIR env var set in the service definition.
{ pkgs, ... }:

pkgs.runCommand "hermes-detail-auto-patch" { } ''
  mkdir -p "$out/agent" "$out/tools/computer_use"
  cp ${./image_routing.py} "$out/agent/image_routing.py"
  cp ${./tool.py}          "$out/tools/computer_use/tool.py"

  # tool_executor.py: opencode-go / Console Go models reject multimodal content
  # in a role:tool message ([400] "Param Incorrect: `text` is not set", which
  # the Matrix gateway surfaces as HTTP 500) but accept the same image in a
  # role:user message.  Moves deferred image parts into a follow-up user
  # message so native vision keeps working instead of falling back to the
  # auxiliary text pipeline.
  cp ${./tool_executor.py} "$out/agent/tool_executor.py"
  cp ${./vision_tools.py}  "$out/tools/vision_tools.py"
''
