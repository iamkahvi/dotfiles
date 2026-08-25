#!/usr/bin/env python3
"""Move a Herdr Space to the front when one of its agents starts working."""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import socket
import sys
import uuid
from typing import Any


def herdr_request(socket_path: str, method: str, params: dict[str, Any]) -> dict[str, Any]:
    request_id = f"mru-spaces:{os.getpid()}:{uuid.uuid4().hex}"
    request = {
        "id": request_id,
        "method": method,
        "params": params,
    }

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(socket_path)
        client.sendall((json.dumps(request, separators=(",", ":")) + "\n").encode())
        with client.makefile("r", encoding="utf-8") as responses:
            line = responses.readline()

    if not line:
        raise RuntimeError(f"Herdr closed the socket while handling {method}")

    response = json.loads(line)
    if response.get("id") != request_id:
        raise RuntimeError(f"Herdr returned an unexpected response id for {method}")
    if error := response.get("error"):
        raise RuntimeError(f"{method} failed: {error.get('code')}: {error.get('message')}")

    result = response.get("result")
    if not isinstance(result, dict):
        raise RuntimeError(f"Herdr returned an invalid result for {method}")
    return result


def move_plan(
    snapshot: dict[str, Any], workspace_id: str
) -> dict[str, Any] | None:
    """Build one atomic move-to-front request, preserving worktree groups."""
    workspaces = snapshot.get("workspaces")
    if not isinstance(workspaces, list):
        return None

    current_ids = [workspace.get("workspace_id") for workspace in workspaces]
    if any(not isinstance(current_id, str) for current_id in current_ids):
        return None

    target = next(
        (
            workspace
            for workspace in workspaces
            if workspace.get("workspace_id") == workspace_id
        ),
        None,
    )
    if target is None:
        return None

    block_ids = [workspace_id]
    target_worktree = target.get("worktree")
    if isinstance(target_worktree, dict) and isinstance(
        target_worktree.get("repo_key"), str
    ):
        repo_key = target_worktree["repo_key"]
        members = [
            workspace
            for workspace in workspaces
            if isinstance(workspace.get("worktree"), dict)
            and workspace["worktree"].get("repo_key") == repo_key
        ]
        parents = [
            workspace["workspace_id"]
            for workspace in members
            if not workspace["worktree"].get("is_linked_worktree", False)
        ]
        children = [
            workspace["workspace_id"]
            for workspace in members
            if workspace["worktree"].get("is_linked_worktree", False)
        ]
        if len(members) >= 2 and parents:
            block_ids = parents + children

    block_id_set = set(block_ids)
    remaining_ids = [
        current_id for current_id in current_ids if current_id not in block_id_set
    ]
    if current_ids == block_ids + remaining_ids:
        return None

    params: dict[str, Any] = {"workspace_ids": block_ids}
    if remaining_ids:
        params["before_workspace_id"] = remaining_ids[0]
    return params


def working_event_target(raw_event: str | None) -> tuple[str, str] | None:
    """Return workspace and pane IDs only for a transition into working."""
    if raw_event is None:
        raise ValueError("HERDR_PLUGIN_EVENT_JSON is missing")

    event = json.loads(raw_event)
    data = event.get("data")
    if event.get("event") != "pane_agent_status_changed" or not isinstance(data, dict):
        raise ValueError("unexpected plugin event")
    if data.get("agent_status") != "working":
        return None

    workspace_id = data.get("workspace_id")
    pane_id = data.get("pane_id")
    if not isinstance(workspace_id, str) or not isinstance(pane_id, str):
        raise ValueError("agent status event is missing workspace or pane id")
    return workspace_id, pane_id


def transition_sequence(
    snapshot: dict[str, Any], workspace_id: str, pane_id: str, last_sequence: int
) -> int | None:
    """Reject superseded, duplicate, and out-of-order working events."""
    agents = snapshot.get("agents")
    if not isinstance(agents, list):
        return None

    sequences = [
        agent.get("state_change_seq")
        for agent in agents
        if isinstance(agent.get("state_change_seq"), int)
    ]
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
    if not isinstance(sequence, int):
        return None

    # Herdr's sequence counter restarts with the server. A lower global maximum
    # therefore means the durable plugin state belongs to an earlier server run.
    maximum = max(sequences, default=-1)
    effective_last = -1 if maximum < last_sequence else last_sequence
    return sequence if sequence > effective_last else None


def read_last_sequence(path: Path) -> int:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (FileNotFoundError, OSError, ValueError):
        return -1


def main() -> int:
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    state_dir = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if not socket_path or not state_dir:
        print(
            "mru-spaces must run as a Herdr plugin with socket and state context",
            file=sys.stderr,
        )
        return 2

    lock_path = Path(state_dir) / "reorder.lock"
    sequence_path = Path(state_dir) / "last-state-change-seq"
    lock_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        target = working_event_target(os.environ.get("HERDR_PLUGIN_EVENT_JSON"))
        if target is None:
            return 0
        workspace_id, pane_id = target

        with lock_path.open("a+") as lock_file:
            # Event commands run concurrently. The lock plus Herdr's monotonic agent
            # state sequence prevents an older transition from winning the race.
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            result = herdr_request(socket_path, "session.snapshot", {})
            snapshot = result.get("snapshot")
            if not isinstance(snapshot, dict):
                raise RuntimeError("session.snapshot returned no snapshot")

            sequence = transition_sequence(
                snapshot,
                workspace_id,
                pane_id,
                read_last_sequence(sequence_path),
            )
            if sequence is None:
                return 0

            if params := move_plan(snapshot, workspace_id):
                herdr_request(socket_path, "workspace.move_block", params)
            sequence_path.write_text(f"{sequence}\n", encoding="utf-8")
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(f"mru-spaces: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
