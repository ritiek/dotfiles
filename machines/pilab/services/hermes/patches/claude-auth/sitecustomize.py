"""
sitecustomize hook — Claude Code OAuth bypass for hermes-agent.
===============================================================

This file is placed on PYTHONPATH for the hermes-agent venv.  It runs once at
Python interpreter startup (before any user code) and hooks the import of
``agent.anthropic_adapter`` so that the billing bypass patch is applied
immediately after the module loads.

The companion ``anthropic_billing_bypass.py`` is found via the
``HERMES_PATCHES_DIR`` environment variable (set in the NixOS service config),
which points at the same store directory holding this file.

Vendored verbatim from hermes-claude-auth (kristianvast/hermes-claude-auth,
rev b7999195) ``sitecustomize_hook.py``.
"""
# hermes-claude-auth managed — do not remove this marker

from __future__ import annotations

import os
import sys

_PATCHES_DIR = os.environ.get(
    "HERMES_PATCHES_DIR",
    os.path.expanduser("~/.hermes/patches"),
)
_TARGET_MODULE = "agent.anthropic_adapter"

if os.path.isdir(_PATCHES_DIR) and _PATCHES_DIR not in sys.path:
    sys.path.insert(0, _PATCHES_DIR)


def _install_hook() -> None:
    try:
        from importlib.abc import MetaPathFinder
        from importlib.util import find_spec
    except ImportError:
        return

    class _ClaudeCodeBypassFinder(MetaPathFinder):
        _patched = False

        def find_spec(self, fullname, path=None, target=None):  # type: ignore[override]
            if fullname != _TARGET_MODULE or self._patched:
                return None

            # Temporarily remove ourselves to avoid recursion during find_spec.
            if self in sys.meta_path:
                sys.meta_path.remove(self)
            try:
                spec = find_spec(fullname)
            finally:
                if self not in sys.meta_path:
                    sys.meta_path.insert(0, self)

            if spec is None or spec.loader is None:
                return None

            original_exec = getattr(spec.loader, "exec_module", None)
            if not callable(original_exec):
                return None

            finder = self

            def patched_exec(module):  # type: ignore[no-untyped-def]
                original_exec(module)
                finder._patched = True
                try:
                    import anthropic_billing_bypass

                    anthropic_billing_bypass.apply_patches(module)
                except Exception as exc:
                    import traceback

                    sys.stderr.write(
                        f"[hermes-claude-auth] bypass failed: "
                        f"{type(exc).__name__}: {exc}\n"
                    )
                    traceback.print_exc(file=sys.stderr)

            spec.loader.exec_module = patched_exec  # type: ignore[attr-defined]
            return spec

    sys.meta_path.insert(0, _ClaudeCodeBypassFinder())


try:
    _install_hook()
except Exception as _exc:
    sys.stderr.write(f"[hermes-claude-auth] hook install failed: {_exc}\n")


# Gateway overlay: inject patched gateway modules from the overlay directory
# into sys.modules after the real gateway package is imported.  A simple
# sys.path prepend does not work because the venv's gateway/ has __init__.py
# (regular package) which wins over the overlay's namespace package regardless
# of PYTHONPATH ordering.  Instead we use a MetaPathFinder that rewrites the
# module spec's origin for the two patched modules.
try:
    _OVERLAY_DIR = os.environ.get("HERMES_GATEWAY_OVERLAY_DIR", "")

    if _OVERLAY_DIR and os.path.isdir(_OVERLAY_DIR):
        from importlib.util import spec_from_file_location

        _OVERLAY_MODULES = {
            "gateway.config": os.path.join(_OVERLAY_DIR, "gateway", "config.py"),
            "gateway.platforms.matrix": os.path.join(
                _OVERLAY_DIR, "gateway", "platforms", "matrix.py"
            ),
        }

        class _GatewayOverlayFinder:
            def find_spec(self, fullname, path=None, target=None):
                overlay_path = _OVERLAY_MODULES.get(fullname)
                if overlay_path and os.path.isfile(overlay_path):
                    return spec_from_file_location(fullname, overlay_path)
                return None

            def find_module(self, fullname, path=None):
                return None

        sys.meta_path.insert(0, _GatewayOverlayFinder())
except Exception as _exc:
    sys.stderr.write(f"[hermes-gateway-overlay] hook install failed: {_exc}\n")


# Anchor 'cron' package before plugin adapters shadow it.
# Multiple plugin adapters (discord, raft, slack, telegram, whatsapp) each do
# sys.path.insert(0, <pkg>/plugins/) at module load time inside gateway.run.
# 'cron' is lazily imported, so by the time it first resolves, plugins/cron
# (which lacks scheduler_provider) wins over the real cron package in the venv.
# Pre-importing here anchors cron in sys.modules with the correct venv path.
try:
    import cron as _cron_anchor  # noqa: F401
    del _cron_anchor
except Exception:
    pass

# Pre-load libopus for discord.py voice channel support.
# ctypes.util.find_library("opus") returns None on NixOS, so we load explicitly.
try:
    import discord.opus as _discord_opus
    if not _discord_opus.is_loaded():
        _discord_opus.load_opus("/nix/store/ra5vs7g3r55qsnwrzk201929d8w8x44z-libopus-1.6.1/lib/libopus.so.0")
except Exception:
    pass
