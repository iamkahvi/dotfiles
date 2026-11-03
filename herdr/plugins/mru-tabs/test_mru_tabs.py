from concurrent.futures import ThreadPoolExecutor
import itertools
import json
import os
from pathlib import Path
import socketserver
import subprocess
import sys
import tempfile
import threading
import unittest

from mru_tabs import event_target, move_plan, read_last_sequence, working_transition


SCRIPT = Path(__file__).with_name("mru_tabs.py")


def tab(workspace, number, label="shell"):
    return {
        "workspace_id": workspace,
        "tab_id": f"{workspace}:t{number}",
        "number": number,
        "label": label,
    }


def agent(workspace="w1", pane=2, tab_number=2, sequence=12, status="working"):
    return {
        "workspace_id": workspace,
        "pane_id": f"{workspace}:p{pane}",
        "tab_id": f"{workspace}:t{tab_number}",
        "state_change_seq": sequence,
        "agent_status": status,
    }


def event(workspace="w1", pane=2, status="working"):
    return json.dumps({
        "event": "pane_agent_status_changed",
        "data": {
            "type": "pane_agent_status_changed",
            "workspace_id": workspace,
            "pane_id": f"{workspace}:p{pane}",
            "agent_status": status,
        },
    })


def tab_event(name="tab_moved", workspace="w1", number=1, label="shell"):
    record = tab(workspace, number, label)
    data = {"tab": record} if name == "tab_created" else record
    return json.dumps({"event": name, "data": {"type": name, **data}})


class MovePlanTest(unittest.TestCase):
    def test_moves_only_target_tab_to_index_zero(self):
        snapshot = {"tabs": [tab("w2", 1, "TODO"), tab("w1", 3), tab("w1", 2), tab("w1", 1)]}
        self.assertEqual(
            move_plan(snapshot, "w1", "w1:t2"),
            [{"tab_id": "w1:t2", "insert_index": 0}],
        )

    def test_uses_workspace_display_order_not_tab_number(self):
        snapshot = {"tabs": [tab("w2", 1), tab("w1", 3), tab("w1", 1)]}
        self.assertEqual(move_plan(snapshot, "w1", "w1:t3"), [])

    def test_does_nothing_for_single_missing_or_wrong_workspace_tab(self):
        for tabs, target in [
            ([tab("w1", 1)], "w1:t1"),
            ([tab("w1", 1)], "missing"),
            ([tab("w2", 1)], "w2:t1"),
            ([], "w1:t1"),
            (None, "w1:t1"),
        ]:
            with self.subTest(tabs=tabs, target=target):
                self.assertEqual(move_plan({"tabs": tabs}, "w1", target), [])

    def test_promotes_agent_after_todo(self):
        snapshot = {"tabs": [tab("w1", 1, "TODO"), tab("w1", 2), tab("w1", 3)]}
        self.assertEqual(move_plan(snapshot, "w1", "w1:t3"),
                         [{"tab_id": "w1:t3", "insert_index": 1}])
        self.assertEqual(move_plan(snapshot, "w1", "w1:t2"), [])

    def test_restores_displaced_todo_even_if_agent_is_already_first(self):
        snapshot = {"tabs": [tab("w1", 1), tab("w1", 2), tab("w1", 3, "TODO")]}
        self.assertEqual(move_plan(snapshot, "w1", "w1:t1"),
                         [{"tab_id": "w1:t3", "insert_index": 0}])

    def test_only_exact_todo_label_is_pinned(self):
        for label in ["todo", "Todo", "TODO notes", " TODO", "TODO "]:
            with self.subTest(label=label):
                snapshot = {"tabs": [tab("w1", 1, label), tab("w1", 2)]}
                self.assertEqual(move_plan(snapshot, "w1", "w1:t2"),
                                 [{"tab_id": "w1:t2", "insert_index": 0}])

    def test_all_orders_preserve_todo_prefix_and_remaining_relative_order(self):
        records = [tab("w1", 1, "TODO"), tab("w1", 2),
                   tab("w1", 3, "TODO"), tab("w1", 4)]
        for tabs in itertools.permutations(records):
            for target in [None, "missing", *(t["tab_id"] for t in tabs)]:
                with self.subTest(tabs=tabs, target=target):
                    current = [t["tab_id"] for t in tabs]
                    pinned = [t["tab_id"] for t in tabs if t["label"] == "TODO"]
                    rest = [tid for tid in current if tid not in pinned]
                    if target in rest:
                        rest.remove(target)
                        rest.insert(0, target)
                    snapshot = {"tabs": list(tabs)}
                    original = json.dumps(snapshot)
                    for move in move_plan(snapshot, "w1", target):
                        current.remove(move["tab_id"])
                        current.insert(move["insert_index"], move["tab_id"])
                    self.assertEqual(current, pinned + rest)
                    self.assertEqual(json.dumps(snapshot), original)
                    by_id = {t["tab_id"]: t for t in tabs}
                    reordered = {"tabs": [by_id[tid] for tid in current]}
                    self.assertEqual(move_plan(reordered, "w1", target), [])


class EventTargetTest(unittest.TestCase):
    def test_extracts_working_pane_without_requiring_tab_context(self):
        self.assertEqual(event_target(event()), ("w1", "w1:p2"))

    def test_tab_events_request_pinning_without_promoting_an_agent(self):
        for name in ["tab_created", "tab_renamed", "tab_moved"]:
            with self.subTest(name=name):
                self.assertEqual(event_target(tab_event(name)), ("w1", None))

    def test_ignores_other_statuses(self):
        for status in ["idle", "done", "blocked", "unknown"]:
            with self.subTest(status=status):
                self.assertIsNone(event_target(event(status=status)))

    def test_rejects_invalid_event_context(self):
        missing_pane = json.loads(event())
        del missing_pane["data"]["pane_id"]
        for raw in [None, "not json", "null", "[]", "{}", json.dumps(missing_pane),
                    '{"event":"tab_focused","data":{}}',
                    '{"event":"tab_created","data":{"tab":null}}',
                    '{"event":"tab_moved","data":{}}']:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                event_target(raw)


class WorkingTransitionTest(unittest.TestCase):
    def test_resolves_split_pane_to_its_live_tab(self):
        snapshot = {"agents": [agent(pane=7, tab_number=3)]}
        self.assertEqual(working_transition(snapshot, "w1", "w1:p7", 10), ("w1:t3", 12))

    def test_rejects_duplicate_older_superseded_and_missing_agents(self):
        for agents, last in [
            ([agent()], 12),
            ([agent()], 13),
            ([agent(status="done")], 10),
            ([agent(workspace="w2")], 10),
            ([], 10),
            (None, 10),
        ]:
            with self.subTest(agents=agents, last=last):
                self.assertIsNone(working_transition({"agents": agents}, "w1", "w1:p2", last))

    def test_requires_sequence_and_tab_id(self):
        for key, value in [("state_change_seq", None), ("state_change_seq", True),
                           ("state_change_seq", "12"), ("tab_id", None)]:
            current = agent()
            current[key] = value
            with self.subTest(key=key, value=value):
                self.assertIsNone(working_transition({"agents": [current]}, "w1", "w1:p2", -1))

    def test_lower_live_maximum_does_not_imply_a_server_restart(self):
        self.assertIsNone(working_transition({"agents": [agent(sequence=2)]}, "w1", "w1:p2", 100))


class StateTest(unittest.TestCase):
    def test_requires_matching_socket_identity_and_valid_sequence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            identity = [1, 2, 3]
            self.assertEqual(read_last_sequence(path, identity), -1)
            for content, expected in [
                ("not json", -1),
                ("[]", -1),
                ('{"server_identity":[1,2,3],"sequence":12}', 12),
                ('{"server_identity":[1,2,4],"sequence":12}', -1),
                ('{"server_identity":[1,2,3],"sequence":true}', -1),
                ('{"server_identity":[1,2,3],"sequence":-2}', -1),
            ]:
                with self.subTest(content=content):
                    path.write_text(content)
                    self.assertEqual(read_last_sequence(path, identity), expected)


class PluginTest(unittest.TestCase):
    """Run the actual hook process against a temporary newline-JSON socket."""

    def setUp(self):
        # Keep the Unix socket path under macOS's length limit.
        self.directory = tempfile.TemporaryDirectory(prefix="mru-tabs-", dir="/tmp")
        self.addCleanup(self.directory.cleanup)
        self.socket_path = Path(self.directory.name) / "herdr.sock"
        self.snapshot = {
            "focused_workspace_id": "w2",
            "focused_tab_id": "w2:t1",
            "focused_pane_id": "w2:p1",
            "workspaces": [{"workspace_id": "w2"}, {"workspace_id": "w1"}],
            "tabs": [tab("w2", 1), tab("w2", 2), tab("w1", 1), tab("w1", 2), tab("w1", 3)],
            "agents": [agent()],
        }
        self.requests = []
        self.reply_fault = None
        self.move_error = False
        self.start_server()
        self.addCleanup(self.stop_server)

    def start_server(self):
        owner = self

        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                request = json.loads(self.rfile.readline())
                owner.requests.append(request)
                response = {"id": request["id"]}
                if owner.reply_fault == "eof":
                    return
                if owner.reply_fault == "id":
                    response["id"] = "wrong-id"
                if request["method"] == "session.snapshot":
                    response["result"] = {"snapshot": owner.snapshot}
                    if owner.reply_fault == "snapshot":
                        response["result"] = {}
                elif request["method"] == "tab.move":
                    if owner.move_error:
                        response["error"] = {"code": "not_found", "message": "tab closed"}
                    else:
                        params = request["params"]
                        tabs = owner.snapshot["tabs"]
                        target = next(t for t in tabs if t["tab_id"] == params["tab_id"])
                        tabs.remove(target)
                        first = next(i for i, t in enumerate(tabs)
                                     if t["workspace_id"] == target["workspace_id"])
                        tabs.insert(first + params["insert_index"], target)
                        response["result"] = {"type": "tab_moved", "tabs": tabs}
                else:
                    response["error"] = {"code": "unexpected_method"}
                if owner.reply_fault == "result":
                    response["result"] = []
                self.wfile.write((json.dumps(response) + "\n").encode())

        self.server = socketserver.UnixStreamServer(str(self.socket_path), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.01})
        self.thread.start()

    def stop_server(self):
        self.server.shutdown()
        self.thread.join(timeout=5)
        self.server.server_close()
        self.socket_path.unlink(missing_ok=True)

    def invoke(self, raw=None, **overrides):
        env = {
            **os.environ,
            "HERDR_SOCKET_PATH": str(self.socket_path),
            "HERDR_PLUGIN_STATE_DIR": str(Path(self.directory.name) / "state"),
            "HERDR_PLUGIN_EVENT_JSON": event() if raw is None else raw,
            # Deliberately incorrect focused context must never affect the target.
            "HERDR_WORKSPACE_ID": "w2",
            "HERDR_TAB_ID": "w2:t1",
            **overrides,
        }
        return subprocess.run([sys.executable, str(SCRIPT)], env=env,
                              capture_output=True, text=True, timeout=10)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")

    def moves(self):
        return [r["params"] for r in self.requests if r["method"] == "tab.move"]

    def test_moves_target_without_focusing_or_reordering_workspaces(self):
        workspaces = self.snapshot["workspaces"][:]
        self.assert_success(self.invoke())
        self.assertEqual([r["method"] for r in self.requests], ["session.snapshot", "tab.move"])
        self.assertEqual(self.moves(), [{"tab_id": "w1:t2", "insert_index": 0}])
        self.assertEqual([t["tab_id"] for t in self.snapshot["tabs"]],
                         ["w2:t1", "w2:t2", "w1:t2", "w1:t1", "w1:t3"])
        self.assertEqual(self.snapshot["workspaces"], workspaces)
        self.assertEqual(self.snapshot["focused_tab_id"], "w2:t1")

    def test_working_agent_stays_after_todo(self):
        self.snapshot["tabs"][2]["label"] = "TODO"
        self.assert_success(self.invoke(event(pane=3)))  # No live agent: pin only.
        self.snapshot["agents"] = [agent(pane=3, tab_number=3)]
        self.assert_success(self.invoke(event(pane=3)))
        self.assertEqual(self.moves(), [{"tab_id": "w1:t3", "insert_index": 1}])
        self.assertEqual([t["tab_id"] for t in self.snapshot["tabs"]][2:],
                         ["w1:t1", "w1:t3", "w1:t2"])

    def test_tab_events_restore_todo_and_settle_without_a_move_loop(self):
        for name in ["tab_created", "tab_renamed", "tab_moved"]:
            with self.subTest(name=name):
                self.snapshot["tabs"] = [tab("w1", 1), tab("w1", 2), tab("w1", 3, "TODO")]
                self.requests.clear()
                # Pinning must work without any agent or new working sequence.
                self.snapshot["agents"] = []
                self.assert_success(self.invoke(tab_event(name, number=3, label="TODO")))
                self.assertEqual(self.moves(), [{"tab_id": "w1:t3", "insert_index": 0}])
                self.assert_success(self.invoke(tab_event()))
                self.assertEqual(len(self.moves()), 1)
                self.assertEqual(self.snapshot["focused_tab_id"], "w2:t1")

    def test_tab_event_does_not_consume_agent_transition(self):
        self.snapshot["tabs"][2]["label"] = "TODO"
        self.assert_success(self.invoke(tab_event()))
        self.assert_success(self.invoke(event(pane=3)))
        self.snapshot["agents"] = [agent(pane=3, tab_number=3)]
        self.assert_success(self.invoke(event(pane=3)))
        self.assertEqual(self.moves(), [{"tab_id": "w1:t3", "insert_index": 1}])

    def test_duplicate_working_event_still_repairs_displaced_todo(self):
        self.assert_success(self.invoke())
        self.snapshot["tabs"][-1]["label"] = "TODO"
        self.assert_success(self.invoke())
        self.assertEqual(self.moves()[-1], {"tab_id": "w1:t3", "insert_index": 0})
        self.assertEqual([t["tab_id"] for t in self.snapshot["tabs"]][2:],
                         ["w1:t3", "w1:t2", "w1:t1"])

    def test_non_working_event_never_contacts_server(self):
        self.assert_success(self.invoke(event(status="done")))
        self.assertEqual(self.requests, [])

    def test_superseded_event_does_not_move_tab(self):
        self.snapshot["agents"][0]["agent_status"] = "done"
        self.assert_success(self.invoke())
        self.assertEqual(self.moves(), [])

    def test_duplicate_event_does_not_undo_a_manual_reorder(self):
        self.assert_success(self.invoke())
        tabs = self.snapshot["tabs"]
        tabs.append(tabs.pop(2))  # User moves the working tab back to the end.
        self.assert_success(self.invoke())
        self.assertEqual(len(self.moves()), 1)
        self.assertEqual(tabs[-1]["tab_id"], "w1:t2")

    def test_older_event_is_ignored_even_after_newest_agent_closes(self):
        self.assert_success(self.invoke())
        self.snapshot["agents"] = [agent(pane=3, tab_number=3, sequence=10)]
        self.assert_success(self.invoke(event(pane=3)))
        self.assertEqual(len(self.moves()), 1)

    def test_a_later_working_transition_moves_the_same_tab_again(self):
        self.assert_success(self.invoke())
        self.snapshot["agents"].append(agent(pane=3, tab_number=3, sequence=15))
        self.assert_success(self.invoke(event(pane=3)))
        self.snapshot["agents"][0]["state_change_seq"] = 20
        self.assert_success(self.invoke())
        self.assertEqual([m["tab_id"] for m in self.moves()],
                         ["w1:t2", "w1:t3", "w1:t2"])

    def test_already_first_transition_still_updates_watermark(self):
        self.snapshot["agents"] = [agent(pane=1, tab_number=1, sequence=20), agent()]
        self.assert_success(self.invoke(event(pane=1)))
        self.assert_success(self.invoke())
        self.assertEqual(self.moves(), [])

    def test_workspaces_have_independent_watermarks(self):
        self.snapshot["agents"].append(agent(workspace="w2", sequence=5))
        self.assert_success(self.invoke())
        self.assert_success(self.invoke(event(workspace="w2")))
        self.assertEqual([m["tab_id"] for m in self.moves()], ["w1:t2", "w2:t2"])

    def test_sessions_with_same_workspace_ids_have_independent_watermarks(self):
        self.assert_success(self.invoke())
        self.stop_server()
        self.socket_path = Path(self.directory.name) / "named-session.sock"
        self.start_server()
        self.snapshot["agents"] = [agent(pane=3, tab_number=3, sequence=1)]
        self.assert_success(self.invoke(event(pane=3)))
        self.assertEqual([m["tab_id"] for m in self.moves()], ["w1:t2", "w1:t3"])

    def test_recreated_socket_resets_watermark(self):
        self.assert_success(self.invoke())
        self.stop_server()
        self.start_server()
        self.snapshot["agents"] = [agent(pane=3, tab_number=3, sequence=1)]
        self.assert_success(self.invoke(event(pane=3)))
        self.assertEqual([m["tab_id"] for m in self.moves()], ["w1:t2", "w1:t3"])

    def test_failed_move_does_not_consume_transition(self):
        self.move_error = True
        result = self.invoke()
        self.assertEqual(result.returncode, 1)
        self.assertIn("tab.move failed", result.stderr)
        self.move_error = False
        self.assert_success(self.invoke())
        self.assertEqual(len(self.moves()), 2)
        self.assertEqual(self.snapshot["tabs"][2]["tab_id"], "w1:t2")

    def test_concurrent_duplicate_hooks_move_once(self):
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: self.invoke(), range(2)))
        for result in results:
            self.assert_success(result)
        self.assertEqual(len(self.moves()), 1)

    def test_invalid_responses_fail_without_consuming_transition(self):
        for fault in ["eof", "id", "result", "snapshot"]:
            with self.subTest(fault=fault):
                self.reply_fault = fault
                result = self.invoke()
                self.assertEqual(result.returncode, 1)
                self.assertIn("mru-tabs:", result.stderr)
        self.assertEqual(self.moves(), [])
        self.reply_fault = None
        self.assert_success(self.invoke())
        self.assertEqual(len(self.moves()), 1)

    def test_missing_runtime_context_and_malformed_event_fail_cleanly(self):
        self.assertEqual(self.invoke(HERDR_SOCKET_PATH="").returncode, 2)
        result = self.invoke("null")
        self.assertEqual(result.returncode, 1)
        self.assertIn("unexpected plugin event", result.stderr)
        self.assertEqual(self.requests, [])


if __name__ == "__main__":
    unittest.main()
