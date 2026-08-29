#!/usr/bin/env python3
"""Unit tests for the pi-panel toggle decisions."""

from __future__ import annotations

import json
import os
import unittest
from unittest import mock

import toggle


class PickPanelTests(unittest.TestCase):
    def test_returns_none_without_panel(self) -> None:
        panes = [{"pane_id": "w1:p1", "tab_id": "w1:t1", "title": "zsh"}]
        self.assertIsNone(toggle.pick_panel(panes, "w1:t1"))

    def test_matches_tab_and_title(self) -> None:
        panes = [
            {"pane_id": "w1:p1", "tab_id": "w1:t1", "title": "zsh"},
            {"pane_id": "w1:p2", "tab_id": "w1:t1", "title": "pi"},
            {"pane_id": "w2:p1", "tab_id": "w2:t1", "title": "pi"},
        ]
        panel = toggle.pick_panel(panes, "w1:t1")
        assert panel is not None
        self.assertEqual(panel["pane_id"], "w1:p2")


class DecideTests(unittest.TestCase):
    def test_open_when_missing(self) -> None:
        self.assertEqual(toggle.decide(None), "open")

    def test_focus_when_unfocused(self) -> None:
        self.assertEqual(toggle.decide({"focused": False, "agent_status": "idle"}), "focus")

    def test_keep_when_working(self) -> None:
        self.assertEqual(
            toggle.decide({"focused": True, "agent_status": "working"}), "keep"
        )

    def test_close_when_idle(self) -> None:
        self.assertEqual(toggle.decide({"focused": True, "agent_status": "idle"}), "close")

    def test_close_when_no_agent_detected(self) -> None:
        self.assertEqual(
            toggle.decide({"focused": True, "agent_status": "unknown"}), "close"
        )


class SplitDirectionTests(unittest.TestCase):
    def run_layout(self, width: int) -> str:
        payload = {
            "layout": {
                "panes": [
                    {
                        "pane_id": "w1:p1",
                        "focused": True,
                        "rect": {"x": 0, "y": 0, "width": width, "height": 40},
                    }
                ]
            }
        }
        with mock.patch.object(toggle, "herdr_json", return_value=payload):
            return toggle.split_direction("w1:p1")

    def test_wide_pane_splits_right(self) -> None:
        self.assertEqual(self.run_layout(180), "right")

    def test_narrow_pane_splits_down(self) -> None:
        self.assertEqual(self.run_layout(60), "down")

    def test_unknown_layout_splits_right(self) -> None:
        with mock.patch.object(toggle, "herdr_json", side_effect=toggle.ToggleError("boom")):
            self.assertEqual(toggle.split_direction("w1:p1"), "right")


class InvocationContextTests(unittest.TestCase):
    def test_reads_context_json(self) -> None:
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": json.dumps(
                {
                    "tab_id": "w1:t1",
                    "focused_pane_id": "w1:p1",
                    "focused_pane_cwd": "/tmp/project",
                }
            ),
        }
        with mock.patch.dict(os.environ, env, clear=False):
            self.assertEqual(
                toggle.invocation_context(), ("w1:t1", "w1:p1", "/tmp/project")
            )

    def test_falls_back_to_herdr_env_vars(self) -> None:
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": "",
            "HERDR_TAB_ID": "w9:t2",
            "HERDR_PANE_ID": "w9:p3",
        }
        with mock.patch.dict(os.environ, env, clear=False):
            self.assertEqual(toggle.invocation_context(), ("w9:t2", "w9:p3", None))

    def test_raises_without_context(self) -> None:
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": "",
            "HERDR_TAB_ID": "",
            "HERDR_PANE_ID": "",
        }
        with mock.patch.dict(os.environ, env, clear=False):
            with self.assertRaises(toggle.ToggleError):
                toggle.invocation_context()


class OpenPanelArgsTests(unittest.TestCase):
    def test_passes_cwd_and_direction(self) -> None:
        captured: list[list[str]] = []

        def fake_herdr(*args: str) -> dict:
            captured.append(list(args))
            return {"plugin_pane": {"pane": {"pane_id": "w1:p9"}}}

        with mock.patch.object(toggle, "herdr_json", side_effect=fake_herdr):
            with mock.patch.object(toggle, "split_direction", return_value="right"):
                pane_id = toggle.open_panel("w1:p1", "/tmp/project")

        self.assertEqual(pane_id, "w1:p9")
        args = captured[0]
        self.assertIn("--cwd", args)
        self.assertEqual(args[args.index("--cwd") + 1], "/tmp/project")
        self.assertIn("--direction", args)
        self.assertEqual(args[args.index("--direction") + 1], "right")

    def test_omits_cwd_when_unknown(self) -> None:
        captured: list[list[str]] = []

        def fake_herdr(*args: str) -> dict:
            captured.append(list(args))
            return {"plugin_pane": {"pane": {"pane_id": "w1:p9"}}}

        with mock.patch.object(toggle, "herdr_json", side_effect=fake_herdr):
            with mock.patch.object(toggle, "split_direction", return_value="down"):
                toggle.open_panel("w1:p1", None)

        self.assertNotIn("--cwd", captured[0])
        self.assertEqual(captured[0][captured[0].index("--direction") + 1], "down")


if __name__ == "__main__":
    unittest.main()
