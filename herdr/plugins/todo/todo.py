#!/usr/bin/env python3
"""Open Vim in a TODO tab, keeping repository notes in kp_scratch."""

from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import subprocess
import sys


def invocation_context() -> tuple[str, Path]:
    # Actions run in the plugin directory, not the invoking pane's directory.
    context = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}")
    if not isinstance(context, dict):
        raise ValueError("invalid Herdr invocation context")
    workspace = context.get("workspace_id") or os.environ.get("HERDR_WORKSPACE_ID")
    cwd = context.get("focused_pane_cwd") or context.get("workspace_cwd")
    if not workspace or not cwd:
        raise ValueError("run this action from a Herdr workspace with a working directory")
    return workspace, Path(cwd)


def todo_path(cwd: Path) -> Path:
    if not cwd.is_dir():
        raise ValueError(f"working directory does not exist: {cwd}")
    result = subprocess.run(
        ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    directory = cwd
    if result.returncode == 0:
        directory = Path(result.stdout.rstrip("\n")) / "kp_scratch"
    directory.mkdir(parents=True, exist_ok=True)
    return directory / "TODO.md"


def move_tab_first(tab_id: str) -> None:
    # Herdr 0.9 exposes tab.move only through the socket API, not its CLI.
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if not socket_path:
        raise ValueError("HERDR_SOCKET_PATH is missing")
    request = {
        "id": f"todo:move:{tab_id}",
        "method": "tab.move",
        "params": {"tab_id": tab_id, "insert_index": 0},
    }
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(socket_path)
        client.sendall((json.dumps(request) + "\n").encode())
        with client.makefile("r", encoding="utf-8") as responses:
            line = responses.readline()
    if not line:
        raise RuntimeError("Herdr closed the socket while moving the TODO tab")
    response = json.loads(line)
    if response.get("id") != request["id"]:
        raise RuntimeError("Herdr returned an unexpected response id for tab.move")
    if error := response.get("error"):
        raise RuntimeError(f"tab.move failed: {error}")


def open_todo() -> None:
    workspace, cwd = invocation_context()
    path = todo_path(cwd)
    herdr = os.environ.get("HERDR_BIN_PATH") or "herdr"
    result = subprocess.run(
        [
            herdr,
            "plugin", "pane", "open",
            "--plugin", "kahvi.todo",
            "--entrypoint", "todo",
            "--placement", "tab",
            "--workspace", workspace,
            "--cwd", str(cwd),
            "--env", f"HERDR_TODO_FILE={path}",
            "--focus",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    pane = json.loads(result.stdout)["result"]["plugin_pane"]["pane"]
    # A plugin pane title does not set its containing tab's label.
    subprocess.run([herdr, "tab", "rename", pane["tab_id"], "TODO"], check=True)
    move_tab_first(pane["tab_id"])


def main() -> int:
    try:
        open_todo()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"todo: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
