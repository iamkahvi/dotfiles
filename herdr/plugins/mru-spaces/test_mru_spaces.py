import json
import unittest

from mru_spaces import move_plan, transition_sequence, working_event_target


def workspace(workspace_id, *, repo_key=None, linked=False):
    worktree = None
    if repo_key is not None:
        worktree = {
            "repo_key": repo_key,
            "is_linked_worktree": linked,
        }
    return {"workspace_id": workspace_id, "worktree": worktree}


def agent(workspace_id, pane_id, status, sequence):
    return {
        "workspace_id": workspace_id,
        "pane_id": pane_id,
        "agent_status": status,
        "state_change_seq": sequence,
    }


class MovePlanTest(unittest.TestCase):
    def test_moves_target_workspace_before_current_first_workspace(self):
        snapshot = {
            "workspaces": [workspace("w1"), workspace("w2"), workspace("w3")],
        }

        self.assertEqual(
            move_plan(snapshot, "w3"),
            {"workspace_ids": ["w3"], "before_workspace_id": "w1"},
        )

    def test_does_nothing_when_target_workspace_is_already_first(self):
        snapshot = {
            "workspaces": [workspace("w1"), workspace("w2")],
        }

        self.assertIsNone(move_plan(snapshot, "w1"))

    def test_moves_an_entire_worktree_group_with_parent_first(self):
        snapshot = {
            "workspaces": [
                workspace("other"),
                workspace("child-1", repo_key="repo", linked=True),
                workspace("parent", repo_key="repo"),
                workspace("child-2", repo_key="repo", linked=True),
                workspace("tail"),
            ],
        }

        self.assertEqual(
            move_plan(snapshot, "child-2"),
            {
                "workspace_ids": ["parent", "child-1", "child-2"],
                "before_workspace_id": "other",
            },
        )

    def test_treats_an_ungrouped_worktree_as_one_workspace(self):
        snapshot = {
            "workspaces": [
                workspace("other"),
                workspace("child", repo_key="repo", linked=True),
            ],
        }

        self.assertEqual(
            move_plan(snapshot, "child"),
            {"workspace_ids": ["child"], "before_workspace_id": "other"},
        )

    def test_reorders_an_only_group_to_parent_first_without_an_anchor(self):
        snapshot = {
            "workspaces": [
                workspace("child", repo_key="repo", linked=True),
                workspace("parent", repo_key="repo"),
            ],
        }

        self.assertEqual(
            move_plan(snapshot, "child"),
            {"workspace_ids": ["parent", "child"]},
        )

    def test_does_nothing_for_an_unknown_workspace(self):
        snapshot = {"workspaces": [workspace("w1")]}

        self.assertIsNone(move_plan(snapshot, "missing"))


class WorkingEventTargetTest(unittest.TestCase):
    def event(self, status):
        return json.dumps(
            {
                "event": "pane_agent_status_changed",
                "data": {
                    "type": "pane_agent_status_changed",
                    "workspace_id": "w2",
                    "pane_id": "w2:p1",
                    "agent_status": status,
                },
            }
        )

    def test_returns_target_for_working_transition(self):
        self.assertEqual(working_event_target(self.event("working")), ("w2", "w2:p1"))

    def test_ignores_non_working_transition(self):
        self.assertIsNone(working_event_target(self.event("done")))

    def test_rejects_missing_event_context(self):
        with self.assertRaisesRegex(ValueError, "missing"):
            working_event_target(None)


class TransitionSequenceTest(unittest.TestCase):
    def test_accepts_a_new_current_working_transition(self):
        snapshot = {
            "agents": [
                agent("w1", "w1:p1", "idle", 10),
                agent("w2", "w2:p1", "working", 12),
            ]
        }

        self.assertEqual(transition_sequence(snapshot, "w2", "w2:p1", 10), 12)

    def test_rejects_an_out_of_order_transition(self):
        snapshot = {
            "agents": [
                agent("w1", "w1:p1", "working", 12),
                agent("w2", "w2:p1", "working", 10),
            ]
        }

        self.assertIsNone(transition_sequence(snapshot, "w2", "w2:p1", 12))

    def test_rejects_a_superseded_working_event(self):
        snapshot = {"agents": [agent("w2", "w2:p1", "done", 13)]}

        self.assertIsNone(transition_sequence(snapshot, "w2", "w2:p1", 10))

    def test_accepts_a_lower_sequence_after_server_restart(self):
        snapshot = {"agents": [agent("w2", "w2:p1", "working", 2)]}

        self.assertEqual(transition_sequence(snapshot, "w2", "w2:p1", 100), 2)


if __name__ == "__main__":
    unittest.main()
