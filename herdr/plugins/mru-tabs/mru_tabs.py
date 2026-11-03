#!/usr/bin/env python3
"""Keep TODO tabs pinned ahead of Herdr tabs ordered by recent agent work."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
from pathlib import Path
import socket
import sys
import uuid
from typing import Any


def herdr_request(socket_path: str, method: str, params: dict[str, Any]) -> dict[str, Any]:
    request_id = f"mru-tabs:{os.getpid()}:{uuid.uuid4().hex}"
    request = {"id": request_id, "method": method, "params": params}

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(socket_path)
        client.sendall((json.dumps(request, separators=(",", ":")) + "\n").encode())
        with client.makefile("r", encoding="utf-8") as responses:
            line = responses.readline()

    if not line:
        raise RuntimeError(f"Herdr closed the socket while handling {method}")

    response = json.loads(line)
    if not isinstance(response, dict) or response.get("id") != request_id:
        raise RuntimeError(f"Herdr returned an unexpected response id for {method}")
    if error := response.get("error"):
        raise RuntimeError(f"{method} failed: {error}")
    result = response.get("result")
    if not isinstance(result, dict):
        raise RuntimeError(f"Herdr returned an invalid result for {method}")
    return result


def event_target(raw_event: str | None) -> tuple[str, str | None] | None:
    """Resolve a workspace to pin, optionally promoting a newly working pane."""
    if raw_event is None:
        raise ValueError("HERDR_PLUGIN_EVENT_JSON is missing")

    event = json.loads(raw_event)
    if not isinstance(event, dict):
        raise ValueError("unexpected plugin event")
    data = event.get("data")
    if not isinstance(data, dict):
        raise ValueError("unexpected plugin event")

    name = event.get("event")
    pane_id = None
    if name == "pane_agent_status_changed":
        if data.get("agent_status") != "working":
            return None
        pane_id = data.get("pane_id")
        if not isinstance(pane_id, str):
            raise ValueError("agent status event is missing pane id")
    elif name == "tab_created":
        data = data.get("tab")
        if not isinstance(data, dict):
            raise ValueError("tab created event is missing tab")
    elif name not in ("tab_renamed", "tab_moved"):
        raise ValueError("unexpected plugin event")

    workspace_id = data.get("workspace_id")
    if not isinstance(workspace_id, str):
        raise ValueError("plugin event is missing workspace id")
    return workspace_id, pane_id


def working_transition(
    snapshot: dict[str, Any], workspace_id: str, pane_id: str, last_sequence: int
) -> tuple[str, int] | None:
    """Resolve the live tab, rejecting superseded, duplicate, and older events."""
    agents = snapshot.get("agents")
    if not isinstance(agents, list):
        return None
    current = next(
        (
            agent
            for agent in agents
            if agent.get("workspace_id") == workspace_id
            and agent.get("pane_id") == pane_id
        ),
        None,
    )
    if current is None or current.get("agent_status") != "working":
        return None

    sequence = current.get("state_change_seq")
    tab_id = current.get("tab_id")
    if type(sequence) is not int or sequence <= last_sequence:
        return None
    if not isinstance(tab_id, str):
        return None
    return tab_id, sequence


def move_plan(
    snapshot: dict[str, Any], workspace_id: str, tab_id: str | None = None
) -> list[dict[str, Any]]:
    """Pin TODO tabs, then promote the target; preserve all other relative order."""
    tabs = snapshot.get("tabs")
    if not isinstance(tabs, list):
        return []
    # Snapshot order is display order; tab numbers are stable IDs, not positions.
    tabs = [tab for tab in tabs if tab.get("workspace_id") == workspace_id]
    current_ids = [tab["tab_id"] for tab in tabs]
    front_ids = [tab["tab_id"] for tab in tabs if tab.get("label") == "TODO"]
    if tab_id in current_ids and tab_id not in front_ids:
        front_ids.append(tab_id)

    moves = []
    for index, target_id in enumerate(front_ids):
        if current_ids[index] == target_id:
            continue
        moves.append({"tab_id": target_id, "insert_index": index})
        # Plan subsequent moves against the order produced by preceding moves.
        current_ids.remove(target_id)
        current_ids.insert(index, target_id)
    return moves


def read_last_sequence(path: Path, server_identity: list[int]) -> int:
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return -1
    if not isinstance(state, dict) or state.get("server_identity") != server_identity:
        return -1
    sequence = state.get("sequence")
    return sequence if type(sequence) is int and sequence >= 0 else -1


def main() -> int:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    state_dir = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if not socket_path or not state_dir:
        print(
            "mru-tabs must run as a Herdr plugin with socket and state context",
            file=sys.stderr,
        )
        return 2

    try:
        target = event_target(os.environ.get("HERDR_PLUGIN_EVENT_JSON"))
        if target is None:
            return 0
        workspace_id, pane_id = target

        # Plugin state is shared across sessions. Each workspace's tab order needs
        # its own watermark, even though Herdr's agent sequence is server-wide.
        socket_path = str(Path(socket_path).resolve())
        state_key = hashlib.sha256(
            json.dumps([socket_path, workspace_id]).encode()
        ).hexdigest()
        directory = Path(state_dir) / state_key
        directory.mkdir(parents=True, exist_ok=True)
        sequence_path = directory / "last-transition.json"

        with (directory / "reorder.lock").open("a+") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            # A recreated socket invalidates the old sequence on server restart.
            # Do not infer restarts from the largest live agent sequence: closing
            # that agent can lower the maximum without restarting the server.
            stat = Path(socket_path).stat()
            server_identity = [stat.st_dev, stat.st_ino, stat.st_ctime_ns]
            result = herdr_request(socket_path, "session.snapshot", {})
            snapshot = result.get("snapshot")
            if not isinstance(snapshot, dict):
                raise RuntimeError("session.snapshot returned no snapshot")

            transition = None
            if pane_id is not None:
                transition = working_transition(
                    snapshot,
                    workspace_id,
                    pane_id,
                    read_last_sequence(sequence_path, server_identity),
                )
            tab_id = transition[0] if transition else None
            # Pinning is independent of agent recency. Our own tab.moved hooks
            # settle without more moves once the TODO prefix is restored.
            for params in move_plan(snapshot, workspace_id, tab_id):
                herdr_request(socket_path, "tab.move", params)
            if transition is None:
                return 0
            _, sequence = transition

            # Record already-frontmost transitions too, but never failed moves.
            temporary_path = sequence_path.with_suffix(".tmp")
            temporary_path.write_text(
                json.dumps({"server_identity": server_identity, "sequence": sequence})
                + "\n",
                encoding="utf-8",
            )
            temporary_path.replace(sequence_path)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"mru-tabs: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
