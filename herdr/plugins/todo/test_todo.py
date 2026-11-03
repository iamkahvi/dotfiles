#!/usr/bin/env python3
"""Tests for TODO placement and Herdr invocation routing."""

from __future__ import annotations

import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import todo


class TodoPathTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="herdr todo '")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        # Do not let the caller's Git environment/config affect test repositories.
        env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        patch = mock.patch.dict(os.environ, env, clear=True)
        patch.start()
        self.addCleanup(patch.stop)

    def git(self, *args: str) -> None:
        subprocess.run(
            ["git", "-C", str(self.root), *args],
            check=True, capture_output=True, text=True,
        )

    def test_non_repository_uses_current_directory(self) -> None:
        self.assertEqual(todo.todo_path(self.root), self.root / "TODO.md")
        self.assertFalse((self.root / "kp_scratch").exists())

    def test_repository_creates_scratch_directory(self) -> None:
        self.git("init")
        self.assertEqual(todo.todo_path(self.root), self.root / "kp_scratch" / "TODO.md")
        self.assertTrue((self.root / "kp_scratch").is_dir())

    def test_repository_subdirectory_uses_repository_root(self) -> None:
        self.git("init")
        nested = self.root / "src" / "nested"
        nested.mkdir(parents=True)
        self.assertEqual(todo.todo_path(nested), self.root / "kp_scratch" / "TODO.md")
        self.assertFalse((nested / "kp_scratch").exists())

    def test_worktree_uses_its_own_root(self) -> None:
        self.git("init")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "test")
        worktree = self.root / "linked worktree"
        self.git("worktree", "add", "--detach", str(worktree))
        nested = worktree / "src"
        nested.mkdir()
        self.assertEqual(todo.todo_path(nested), worktree / "kp_scratch" / "TODO.md")

    def test_existing_notes_are_not_modified(self) -> None:
        self.git("init")
        path = todo.todo_path(self.root)
        path.write_text("- [ ] Keep these notes\n")
        self.assertEqual(todo.todo_path(self.root), path)
        self.assertEqual(path.read_text(), "- [ ] Keep these notes\n")

    def test_missing_working_directory_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            todo.todo_path(self.root / "missing")

    def test_scratch_file_is_not_overwritten(self) -> None:
        self.git("init")
        (self.root / "kp_scratch").write_text("keep")
        with self.assertRaises(FileExistsError):
            todo.todo_path(self.root)
        self.assertEqual((self.root / "kp_scratch").read_text(), "keep")


class MoveTabTests(unittest.TestCase):
    def move_with_response(self, response: str) -> mock.MagicMock:
        with (
            mock.patch.dict(os.environ, {"HERDR_SOCKET_PATH": "/tmp/herdr.sock"}),
            mock.patch.object(todo.socket, "socket") as socket,
        ):
            client = socket.return_value.__enter__.return_value
            client.makefile.return_value = io.StringIO(response)
            todo.move_tab_first("w2:t9")
        return client

    def test_moves_only_target_tab_to_zero_index(self) -> None:
        client = self.move_with_response(json.dumps({
            "id": "todo:move:w2:t9", "result": {"type": "tab_info"},
        }) + "\n")
        client.connect.assert_called_once_with("/tmp/herdr.sock")
        client.settimeout.assert_called_once_with(5)
        client.sendall.assert_called_once()
        request = json.loads(client.sendall.call_args.args[0])
        self.assertEqual(request, {
            "id": "todo:move:w2:t9",
            "method": "tab.move",
            "params": {"tab_id": "w2:t9", "insert_index": 0},
        })

    def test_missing_socket_context_is_rejected(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "HERDR_SOCKET_PATH"):
                todo.move_tab_first("w2:t9")

    def test_server_errors_are_reported(self) -> None:
        response = {
            "id": "todo:move:w2:t9",
            "error": {"code": "tab_not_found", "message": "Tab closed"},
        }
        with self.assertRaisesRegex(RuntimeError, "tab_not_found"):
            self.move_with_response(json.dumps(response) + "\n")

    def test_closed_socket_and_mismatched_response_are_rejected(self) -> None:
        for response in ("", '{"id":"unexpected","result":{}}\n'):
            with self.subTest(response=response):
                with self.assertRaises(RuntimeError):
                    self.move_with_response(response)


class InvocationTests(unittest.TestCase):
    def test_focused_context_wins_over_workspace_defaults(self) -> None:
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": json.dumps({
                "workspace_id": "w2",
                "focused_pane_cwd": "/tmp/current directory",
                "workspace_cwd": "/tmp/workspace",
            }),
            "HERDR_WORKSPACE_ID": "w1",
        }
        with mock.patch.dict(os.environ, env, clear=True):
            self.assertEqual(todo.invocation_context(), ("w2", Path("/tmp/current directory")))

    def test_workspace_fallback(self) -> None:
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": json.dumps({"workspace_cwd": "/tmp/workspace"}),
            "HERDR_WORKSPACE_ID": "w1",
        }
        with mock.patch.dict(os.environ, env, clear=True):
            self.assertEqual(todo.invocation_context(), ("w1", Path("/tmp/workspace")))

    def test_missing_or_invalid_context_does_not_use_plugin_directory(self) -> None:
        for raw in ("", "not json", "[]", '{"workspace_id":"w1"}',
                    '{"focused_pane_cwd":"/tmp"}'):
            with self.subTest(raw=raw):
                with mock.patch.dict(os.environ, {"HERDR_PLUGIN_CONTEXT_JSON": raw}, clear=True):
                    with self.assertRaises(ValueError):
                        todo.invocation_context()

    def test_opens_focused_tab_in_invoking_workspace_with_literal_path(self) -> None:
        cwd = Path("/tmp/project's notes $(not-a-command)")
        path = cwd / "kp_scratch" / "TODO.md"
        with (
            mock.patch.dict(os.environ, {"HERDR_BIN_PATH": "/opt/herdr"}),
            mock.patch.object(todo, "invocation_context", return_value=("w2", cwd)),
            mock.patch.object(todo, "todo_path", return_value=path) as resolve,
            mock.patch.object(todo.subprocess, "run") as run,
            mock.patch.object(todo, "move_tab_first") as move,
        ):
            run.return_value.stdout = json.dumps({
                "result": {"plugin_pane": {"pane": {"tab_id": "w2:t9"}}},
            })
            todo.open_todo()
        resolve.assert_called_once_with(cwd)
        move.assert_called_once_with("w2:t9")
        self.assertEqual(run.call_args_list, [
            mock.call([
                "/opt/herdr", "plugin", "pane", "open",
                "--plugin", "kahvi.todo", "--entrypoint", "todo",
                "--placement", "tab", "--workspace", "w2",
                "--cwd", str(cwd), "--env", f"HERDR_TODO_FILE={path}", "--focus",
            ], check=True, capture_output=True, text=True),
            mock.call(["/opt/herdr", "tab", "rename", "w2:t9", "TODO"], check=True),
        ])


if __name__ == "__main__":
    unittest.main()
