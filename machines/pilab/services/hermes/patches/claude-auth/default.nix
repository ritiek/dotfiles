# hermes-claude-auth: in-process monkey-patch that makes hermes-agent's
# OAuth-authenticated Anthropic requests pass the server-side billing
# validator and route to the Claude Max/Pro subscription tier (instead of
# pay-per-token "extra usage").
#
# Replaces the previous meridian Docker proxy on port 3456. The patch is two
# self-contained Python files vendored verbatim from
# github.com/kristianvast/hermes-claude-auth (rev b7999195):
#   - sitecustomize.py          (import hook, must be on PYTHONPATH)
#   - anthropic_billing_bypass.py (the actual bypass, found via HERMES_PATCHES_DIR)
#
# This derivation drops BOTH files into one store directory. Wiring in
# hermes.nix sets PYTHONPATH=<this> (so sitecustomize.py auto-runs at
# interpreter startup) AND HERMES_PATCHES_DIR=<this> (so the hook can import
# anthropic_billing_bypass).
{ pkgs, ... }:

pkgs.runCommand "hermes-claude-auth" { } ''
  mkdir -p "$out"
  cp ${./sitecustomize.py} "$out/sitecustomize.py"
  cp ${./anthropic_billing_bypass.py} "$out/anthropic_billing_bypass.py"
''
