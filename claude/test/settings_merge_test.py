#!/usr/bin/env python3
"""Unit tests for claude/settings_merge.py.

Run via settings_merge_test.sh (which is what run_all_tests.sh discovers), or directly:
    python3 -m unittest discover -s claude/test -p 'settings_merge_test.py'
"""

import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parent.parent / "settings_merge.py"
_spec = importlib.util.spec_from_file_location("settings_merge", MODULE_PATH)
sm = importlib.util.module_from_spec(_spec)
sys.modules["settings_merge"] = sm
_spec.loader.exec_module(sm)


class TestFreshInstall(unittest.TestCase):
    def test_applies_merge_and_seed_to_an_empty_live_file(self):
        frag = {
            "merge": {"permissions": {"allow": ["Bash(ls:*)"]}},
            "seed": {"theme": "dark-daltonized"},
        }
        nxt, state = sm.merge(live={}, fragments=[frag], state={})
        self.assertEqual(nxt["permissions"]["allow"], ["Bash(ls:*)"])
        self.assertEqual(nxt["theme"], "dark-daltonized")

    def test_state_records_only_the_merge_block(self):
        """Seed must stay out of state, or removal would later delete a pref the user owns."""
        frag = {"merge": {"theme": "x"}, "seed": {"model": "y"}}
        _, state = sm.merge(live={}, fragments=[frag], state={})
        self.assertEqual(state, {"theme": "x"})


class TestForeignContent(unittest.TestCase):
    def test_keys_we_never_declare_survive(self):
        live = {
            "extraKnownMarketplaces": {"someone-elses": {"source": {}}},
            "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "their-hook.sh"}]}]},
        }
        frag = {"merge": {"permissions": {"allow": ["Bash(ls:*)"]}}}
        nxt, _ = sm.merge(live=live, fragments=[frag], state={})
        self.assertIn("someone-elses", nxt["extraKnownMarketplaces"])
        self.assertEqual(nxt["hooks"]["Stop"][0]["hooks"][0]["command"], "their-hook.sh")

    def test_our_hook_is_appended_beside_a_foreign_one_on_the_same_event(self):
        live = {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "their-hook.sh"}]}]}}
        frag = {"merge": {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "ours.sh"}]}]}}}
        nxt, _ = sm.merge(live=live, fragments=[frag], state={})
        commands = [h["command"] for group in nxt["hooks"]["Stop"] for h in group["hooks"]]
        self.assertEqual(commands, ["their-hook.sh", "ours.sh"])


class TestSeed(unittest.TestCase):
    def test_seed_does_not_overwrite_a_value_already_present(self):
        """/config changes must survive ./install."""
        frag = {"seed": {"theme": "dark-daltonized"}}
        nxt, _ = sm.merge(live={"theme": "light"}, fragments=[frag], state={})
        self.assertEqual(nxt["theme"], "light")

    def test_merge_does_overwrite(self):
        frag = {"merge": {"permissions": {"defaultMode": "auto"}}}
        nxt, _ = sm.merge(live={"permissions": {"defaultMode": "plan"}}, fragments=[frag], state={})
        self.assertEqual(nxt["permissions"]["defaultMode"], "auto")



class TestRemoval(unittest.TestCase):
    def test_a_rule_dropped_from_the_fragment_is_removed(self):
        live = {"permissions": {"allow": ["Bash(ls:*)", "Bash(gone:*)"]}}
        state = {"permissions": {"allow": ["Bash(ls:*)", "Bash(gone:*)"]}}
        frag = {"merge": {"permissions": {"allow": ["Bash(ls:*)"]}}}
        nxt, _ = sm.merge(live=live, fragments=[frag], state=state)
        self.assertEqual(nxt["permissions"]["allow"], ["Bash(ls:*)"])

    def test_a_rule_we_never_applied_is_left_alone(self):
        """Protects a rule added by hand through /permissions."""
        live = {"permissions": {"allow": ["Bash(ls:*)", "Bash(by-hand:*)"]}}
        state = {"permissions": {"allow": ["Bash(ls:*)"]}}
        frag = {"merge": {"permissions": {"allow": ["Bash(ls:*)"]}}}
        nxt, _ = sm.merge(live=live, fragments=[frag], state=state)
        self.assertIn("Bash(by-hand:*)", nxt["permissions"]["allow"])

    def test_a_scalar_dropped_from_the_fragment_is_removed(self):
        nxt, _ = sm.merge(live={"verbose": True}, fragments=[{"merge": {}}], state={"verbose": True})
        self.assertNotIn("verbose", nxt)

    def test_a_scalar_the_user_changed_is_not_removed(self):
        """We applied True; the live value is False, so the user owns it now."""
        nxt, _ = sm.merge(live={"verbose": False}, fragments=[{"merge": {}}], state={"verbose": True})
        self.assertEqual(nxt["verbose"], False)

    def test_a_hook_dropped_from_the_fragment_is_removed_by_command(self):
        ours = {"hooks": [{"type": "command", "command": "ours.sh"}]}
        theirs = {"hooks": [{"type": "command", "command": "theirs.sh"}]}
        live = {"hooks": {"Stop": [theirs, ours]}}
        state = {"hooks": {"Stop": [ours]}}
        nxt, _ = sm.merge(live=live, fragments=[{"merge": {}}], state=state)
        commands = [h["command"] for g in nxt["hooks"]["Stop"] for h in g["hooks"]]
        self.assertEqual(commands, ["theirs.sh"])

    def test_an_emptied_container_is_pruned(self):
        live = {"permissions": {"allow": ["Bash(gone:*)"]}}
        state = {"permissions": {"allow": ["Bash(gone:*)"]}}
        nxt, _ = sm.merge(live=live, fragments=[{"merge": {}}], state=state)
        self.assertEqual(nxt, {})


class TestIdempotency(unittest.TestCase):
    def test_second_run_is_a_no_op(self):
        frag = {
            "merge": {"permissions": {"allow": ["Bash(ls:*)"]},
                      "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "ours.sh"}]}]}},
            "seed": {"theme": "dark"},
        }
        first, state = sm.merge(live={}, fragments=[frag], state={})
        second, state2 = sm.merge(live=first, fragments=[frag], state=state)
        self.assertEqual(first, second)
        self.assertEqual(state, state2)


class TestPrecedence(unittest.TestCase):
    def test_later_fragment_wins_a_scalar_and_lists_concatenate(self):
        base = {"merge": {"permissions": {"allow": ["a"]}, "permissions_mode": "x"}}
        later = {"merge": {"permissions": {"allow": ["b"]}, "permissions_mode": "y"}}
        nxt, _ = sm.merge(live={}, fragments=[base, later], state={})
        self.assertEqual(nxt["permissions"]["allow"], ["a", "b"])
        self.assertEqual(nxt["permissions_mode"], "y")

class TestMain(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.settings = self.tmp / "settings.json"
        self.state = self.tmp / "state.json"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _fragment(self, name: str, data: dict) -> str:
        path = self.tmp / name
        path.write_text(json.dumps(data))
        return str(path)

    def _run(self, *fragments: str, extra: list[str] | None = None) -> int:
        argv = list(fragments) + ["--settings", str(self.settings), "--state", str(self.state)]
        return sm.main(argv + (extra or []))

    def test_writes_settings_and_state(self):
        frag = self._fragment("00.json", {"merge": {"permissions": {"allow": ["Bash(ls:*)"]}}})
        self.assertEqual(self._run(frag), 0)
        self.assertEqual(json.loads(self.settings.read_text())["permissions"]["allow"], ["Bash(ls:*)"])
        self.assertEqual(json.loads(self.state.read_text())["permissions"]["allow"], ["Bash(ls:*)"])

    def test_second_run_leaves_the_file_byte_identical(self):
        frag = self._fragment("00.json", {"merge": {"permissions": {"allow": ["Bash(ls:*)"]}}}, )
        self._run(frag)
        first = self.settings.read_bytes()
        self._run(frag)
        self.assertEqual(self.settings.read_bytes(), first)

    def test_base_only_run_succeeds_when_the_private_fragment_is_absent(self):
        """The macbook case: indeed/ is not checked out, so only the base fragment is passed."""
        frag = self._fragment("00.json", {"merge": {"permissions": {"allow": ["Bash(ls:*)"]}}})
        self.assertEqual(self._run(frag), 0)
        self.assertIn("permissions", json.loads(self.settings.read_text()))

    def test_no_fragments_is_a_no_op(self):
        self.settings.write_text(json.dumps({"theme": "dark"}))
        self.assertEqual(self._run(), 0)
        self.assertEqual(json.loads(self.settings.read_text()), {"theme": "dark"})

    def test_all_empty_fragments_refuse_to_touch_a_populated_file(self):
        """A fragment blanked by accident must not wipe the live settings."""
        self.settings.write_text(json.dumps({"theme": "dark"}))
        frag = self._fragment("00.json", {"merge": {}, "seed": {}})
        self.assertEqual(self._run(frag), 1)
        self.assertEqual(json.loads(self.settings.read_text()), {"theme": "dark"})

    def test_invalid_fragment_json_aborts_without_writing(self):
        self.settings.write_text(json.dumps({"theme": "dark"}))
        bad = self.tmp / "bad.json"
        bad.write_text("{not json")
        with self.assertRaises(SystemExit):
            self._run(str(bad))
        self.assertEqual(json.loads(self.settings.read_text()), {"theme": "dark"})

    def test_atomic_write_replaces_a_symlink_with_a_real_file(self):
        """Documents why install.conf.yaml must not link this path: the write destroys the link."""
        real = self.tmp / "elsewhere.json"
        real.write_text(json.dumps({"theme": "dark"}))
        self.settings.symlink_to(real)
        frag = self._fragment("00.json", {"merge": {"verbose": True}})
        self._run(frag)
        self.assertFalse(self.settings.is_symlink())
        self.assertTrue(self.settings.is_file())
        self.assertEqual(json.loads(real.read_text()), {"theme": "dark"})

    def test_dry_run_writes_nothing(self):
        self.settings.write_text(json.dumps({"theme": "dark"}))
        frag = self._fragment("00.json", {"merge": {"verbose": True}})
        self.assertEqual(self._run(frag, extra=["--dry-run"]), 0)
        self.assertEqual(json.loads(self.settings.read_text()), {"theme": "dark"})
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
