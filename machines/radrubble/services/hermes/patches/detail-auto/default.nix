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
# NOTE: the old tool_executor.py overlay (move images out of role:tool into a
# follow-up role:user message for Console Go models that 400 on multimodal
# tool content) was DROPPED at the 0.21.0 bump — upstream now handles this
# natively via the provider-profile flag `supports_vision_tool_messages` plus
# runtime learning in `_no_list_tool_content_models` (agent/vision_message_prep.py),
# which explicitly covers Xiaomi MiMo "text is not set".
#
# Loaded via MetaPathFinder in sitecustomize.py (patches/claude-auth/), keyed off
# the HERMES_DETAIL_AUTO_OVERLAY_DIR env var set in the service definition.
{ pkgs, ... }:

pkgs.runCommand "hermes-detail-auto-patch" { } ''
  mkdir -p "$out/agent" "$out/tools/computer_use"
  cp ${./image_routing.py} "$out/agent/image_routing.py"
  cp ${./tool.py}          "$out/tools/computer_use/tool.py"
  cp ${./vision_tools.py}  "$out/tools/vision_tools.py"
''
