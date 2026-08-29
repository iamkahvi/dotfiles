#!/usr/bin/env python3
"""Toggle a pi session side panel in the current Herdr tab.

Runs as the `toggle` action of the kahvi.pi-panel plugin, normally bound to a
keybinding. Behavior:

- No `pi` panel in the current tab: split the focused pane and start pi there,
  in the focused pane's working directory. Splits right for wide panes, down
  for narrow ones. The panel takes focus.
- Panel exists but is not focused: focus it (pi keeps running in the
  background).
- Panel is focused and pi is working: leave it alone.
- Panel is focused and pi is idle (or not detected): close it.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from typing import Any

PLUGIN_ID = os.environ.get("HERDR_PLUGIN_ID", "kahvi.pi-panel")
ENTRYPOINT = "pi"
PANEL_TITLE = "pi"  # must match the manifest [[panes]] title
NARROW_COLS = 100  # split down instead of right below this focused-pane width


class ToggleError(RuntimeError):
    """A Herdr call or context read failed."""


def herdr_json(*args: str) -> dict[str, Any]:
    """Run a Herdr CLI command and return its parsed JSON result."""
    binary = os.environ.get("HERDR_BIN_PATH") or "herdr"
    process = subprocess.run([binary, *args], capture_output=True, text=True)
    if process.returncode != 0:
        detail = (process.stderr or process.stdout).strip()
        raise ToggleError(f"herdr {' '.join(args)} failed: {detail}")
    try:
        payload = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        raise ToggleError(f"herdr {' '.join(args)} returned invalid JSON: {error}") from error
    result = payload.get("result") if isinstance(payload, dict) else None
    return result if isinstance(result, dict) else payload


def load_context() -> dict[str, Any]:
    """Parse HERDR_PLUGIN_CONTEXT_JSON, tolerating absence and bad JSON."""
    raw = os.environ.get("HERDR_PLUGIN_CONTEXT_JSON")
    if not raw:
        return {}
    try:
        context = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return context if isinstance(context, dict) else {}


def invocation_context() -> tuple[str, str, str | None]:
    """Return (tab_id, focused_pane_id, cwd) for this action invocation."""
    context = load_context()
    tab_id = context.get("tab_id") or os.environ.get("HERDR_TAB_ID")
    focused_pane = context.get("focused_pane_id") or os.environ.get("HERDR_PANE_ID")
    cwd = context.get("focused_pane_cwd") or context.get("workspace_cwd")
    if not tab_id or not focused_pane:
        raise ToggleError(
            "invocation has no focused pane context; bind this action to a "
            "Herdr keybinding or run it from inside a Herdr pane"
        )
    return tab_id, focused_pane, cwd or None


def pick_panel(panes: list[dict[str, Any]], tab_id: str) -> dict[str, Any] | None:
    """Return the pi panel pane in the given tab, if any."""
    for pane in panes:
        if pane.get("tab_id") == tab_id and pane.get("title") == PANEL_TITLE:
            return pane
    return None


def decide(panel: dict[str, Any] | None) -> str:
    """Choose open/focus/close/keep from the panel's current state."""
    if panel is None:
        return "open"
    if not panel.get("focused"):
        return "focus"
    return "keep" if panel.get("agent_status") == "working" else "close"


def split_direction(pane_id: str) -> str:
    """Split right for wide panes, down for narrow ones; right when unknown."""
    try:
        layout = herdr_json("pane", "layout", "--pane", pane_id).get("layout") or {}
        panes = layout.get("panes") or []
        rect = next(
            (entry.get("rect") for entry in panes if entry.get("pane_id") == pane_id),
            None,
        )
    except ToggleError:
        return "right"
    if isinstance(rect, dict) and isinstance(rect.get("width"), (int, float)):
        return "down" if rect["width"] < NARROW_COLS else "right"
    return "right"


def open_panel(focused_pane: str, cwd: str | None) -> str:
    """Open the pi panel split and return the new pane id."""
    args = [
        "plugin", "pane", "open",
        "--plugin", PLUGIN_ID,
        "--entrypoint", ENTRYPOINT,
        "--placement", "split",
        "--direction", split_direction(focused_pane),
        "--target-pane", focused_pane,
        "--focus",
    ]
    if cwd:
        args += ["--cwd", cwd]
    plugin_pane = herdr_json(*args).get("plugin_pane") or {}
    pane = plugin_pane.get("pane") or {}
    return pane.get("pane_id") or "unknown-pane"


def main() -> int:
    try:
        tab_id, focused_pane, cwd = invocation_context()
        panes = herdr_json("pane", "list").get("panes") or []
        panel = pick_panel(panes, tab_id)
        action = decide(panel)

        if action == "open":
            pane_id = open_panel(focused_pane, cwd)
            print(f"pi panel opened as {pane_id}")
        elif action == "focus":
            herdr_json("plugin", "pane", "focus", panel["pane_id"])
            print(f"focused pi panel {panel['pane_id']}")
        elif action == "close":
            herdr_json("plugin", "pane", "close", panel["pane_id"])
            print(f"closed pi panel {panel['pane_id']}")
        else:
            print("pi is working; left the panel open")
    except ToggleError as error:
        print(f"pi-panel: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
