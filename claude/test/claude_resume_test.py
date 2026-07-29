#!/usr/bin/env python3
"""Unit tests for claude/functions/claude_resume.py.

Run via claude_resume_test.sh (which is what run_all_tests.sh discovers), or directly:
    python3 -m unittest discover -s claude/test -p 'claude_resume_test.py'
"""

import contextlib
import importlib.util
import io
import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path

# The picker lives beside the shell function rather than on the import path, so load it by file.
# Registering it in sys.modules first is required: @dataclass resolves annotations through there.
MODULE_PATH = Path(__file__).resolve().parent.parent / "functions" / "claude_resume.py"
_spec = importlib.util.spec_from_file_location("claude_resume", MODULE_PATH)
cr = importlib.util.module_from_spec(_spec)
sys.modules["claude_resume"] = cr
_spec.loader.exec_module(cr)

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def strip(text):
    return ANSI.sub("", text)


class StatusTest(unittest.TestCase):
    def test_empty_prompt_is_unknown(self):
        self.assertEqual(cr.classify_status(""), "???")
        self.assertEqual(cr.classify_status("   "), "???")
        self.assertEqual(cr.classify_status(None), "???")

    def test_short_approval_is_done(self):
        for prompt in ("thanks", "perfect", "looks good", "that works", "nice"):
            self.assertEqual(cr.classify_status(prompt), "done", prompt)

    def test_pause_language_is_tbc(self):
        for prompt in ("let's pause here", "wip", "continue this later", "for now"):
            self.assertEqual(cr.classify_status(prompt), "tbc", prompt)

    def test_long_prompt_outranks_weak_approval(self):
        prompt = "thanks for that, but now please also go and update the other seventeen call sites"
        self.assertGreaterEqual(len(prompt), cr.LONG_PROMPT)
        self.assertEqual(cr.classify_status(prompt), "???")

    def test_strong_closer_wins_at_any_length(self):
        prompt = "we're done, and here is a long tail of text to push this prompt past the eighty character cutoff"
        self.assertGreaterEqual(len(prompt), cr.LONG_PROMPT)
        self.assertEqual(cr.classify_status(prompt), "done")

    def test_tbc_outranks_weak_done(self):
        self.assertEqual(cr.classify_status("thanks, pick this up tomorrow"), "tbc")


class PathTest(unittest.TestCase):
    HOME = "/home/u"

    def test_abbreviate_only_at_the_front(self):
        self.assertEqual(cr.abbreviate("/home/u/proj", self.HOME), "~/proj")
        self.assertEqual(cr.abbreviate("/srv/home/u", self.HOME), "/srv/home/u")

    def test_short_path_keeps_last_two_components(self):
        self.assertEqual(cr.short_path("/home/u/a/b/c/leaf", self.HOME), ".../c/leaf")
        self.assertEqual(cr.short_path("/home/u/proj", self.HOME), "~/proj")
        self.assertEqual(cr.short_path("/home/u", self.HOME), "~")
        self.assertEqual(cr.short_path("/srv/worker/deploy", self.HOME), ".../worker/deploy")


class SessionCellTest(unittest.TestCase):
    def session(self, tokens):
        return cr.Session(sid="s", cwd="/home/u", mtime=0, out_tokens=tokens, home="/home/u")

    def test_token_cell_switches_to_k_at_a_thousand(self):
        self.assertEqual(self.session(0).token_cell, "0")
        self.assertEqual(self.session(999).token_cell, "999")
        self.assertEqual(self.session(1000).token_cell, "1k")
        self.assertEqual(self.session(270_000).token_cell, "270k")

    def test_token_level_thresholds_are_exclusive(self):
        self.assertEqual(self.session(100_000).token_level, "")
        self.assertEqual(self.session(100_001).token_level, "warn")
        self.assertEqual(self.session(200_000).token_level, "warn")
        self.assertEqual(self.session(200_001).token_level, "crit")


class TranscriptFixture(unittest.TestCase):
    """Base class that writes throwaway transcripts into a temp projects tree."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = self.tmp.name
        self.projects = Path(self.home) / ".claude" / "projects"
        self.projects.mkdir(parents=True)
        self.addCleanup(self.tmp.cleanup)

    def write(self, sid, entries, subdir="proj", mtime=1_000_000):
        directory = self.projects / subdir
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"{sid}.jsonl"
        with open(path, "w") as handle:
            for entry in entries:
                handle.write(entry if isinstance(entry, str) else json.dumps(entry))
                handle.write("\n")
        os.utime(path, (mtime, mtime))
        return path


class ReadTranscriptTest(TranscriptFixture):
    def test_extracts_every_field_in_one_pass(self):
        path = self.write("sid-1", [
            {"type": "user", "cwd": f"{self.home}/work", "gitBranch": "master",
             "message": {"role": "user", "content": "first prompt"}},
            {"type": "assistant", "message": {"usage": {"output_tokens": 100}}},
            {"type": "ai-title", "aiTitle": "Early title"},
            {"type": "ai-title", "aiTitle": "Final title"},
            {"type": "user", "cwd": "/somewhere/else", "gitBranch": "feature/x"},
            {"type": "assistant", "message": {"usage": {"output_tokens": 50}}},
            {"type": "last-prompt", "lastPrompt": "thanks"},
        ])
        session = cr.read_transcript(path, self.home)
        self.assertEqual(session.sid, "sid-1")
        self.assertEqual(session.cwd, f"{self.home}/work", "first cwd wins — it decides where the transcript lives")
        self.assertEqual(session.branch, "feature/x", "latest branch wins")
        self.assertEqual(session.title, "Final title", "latest ai-title wins")
        self.assertEqual(session.messages, 4)
        self.assertEqual(session.out_tokens, 150)
        self.assertEqual(session.status, "done")

    def test_title_falls_back_to_first_user_text(self):
        path = self.write("sid-2", [
            {"type": "user", "cwd": self.home, "message": {"role": "user", "content": "  needs   collapsing\n now "}},
            {"type": "user", "message": {"role": "user", "content": "later prompt"}},
        ])
        self.assertEqual(cr.read_transcript(path, self.home).title, "needs collapsing now")

    def test_title_falls_back_through_content_blocks(self):
        path = self.write("sid-3", [
            {"type": "user", "cwd": self.home, "message": {"role": "user", "content": [
                {"type": "tool_result", "content": "ignored"},
                {"type": "text", "text": "   "},
                {"type": "text", "text": "block text"},
            ]}},
        ])
        self.assertEqual(cr.read_transcript(path, self.home).title, "block text")

    def test_fields_are_capped(self):
        path = self.write("sid-4", [
            {"type": "user", "cwd": self.home, "gitBranch": "b" * 200,
             "message": {"role": "user", "content": "t" * 200}},
        ])
        session = cr.read_transcript(path, self.home)
        self.assertEqual(len(session.title), cr.FIELD_CAP)
        self.assertEqual(len(session.branch), cr.FIELD_CAP)

    def test_malformed_lines_are_skipped(self):
        path = self.write("sid-5", [
            "{ not json",
            "",
            "[1, 2, 3]",
            {"type": "user", "cwd": self.home, "message": {"role": "user", "content": "survived"}},
        ])
        self.assertEqual(cr.read_transcript(path, self.home).title, "survived")

    def test_transcript_without_cwd_is_unresumable(self):
        path = self.write("sid-6", [{"type": "user", "message": {"role": "user", "content": "no cwd"}}])
        self.assertIsNone(cr.read_transcript(path, self.home))

    def test_empty_transcript_is_unresumable(self):
        self.assertIsNone(cr.read_transcript(self.write("sid-7", []), self.home))


class ScanSessionsTest(TranscriptFixture):
    def test_orders_newest_first_and_skips_subagents(self):
        self.write("old", [{"type": "user", "cwd": self.home}], subdir="a", mtime=1000)
        self.write("new", [{"type": "user", "cwd": self.home}], subdir="b", mtime=3000)
        self.write("mid", [{"type": "user", "cwd": self.home}], subdir="c", mtime=2000)
        self.write("agent", [{"type": "user", "cwd": self.home}], subdir="a/subagents", mtime=9000)
        self.assertEqual([s.sid for s in cr.scan_sessions(self.projects, self.home)], ["new", "mid", "old"])

    def test_ties_break_on_sid_for_stable_order(self):
        for sid in ("zzz", "aaa", "mmm"):
            self.write(sid, [{"type": "user", "cwd": self.home}], subdir=sid, mtime=5000)
        self.assertEqual([s.sid for s in cr.scan_sessions(self.projects, self.home)], ["aaa", "mmm", "zzz"])


class FiltersTest(unittest.TestCase):
    def session(self, title="Refactor the widget", cwd="/home/u/proj/alpha"):
        return cr.Session(sid="s", cwd=cwd, mtime=0, title=title, home="/home/u")

    def test_title_filter_is_case_insensitive(self):
        self.assertTrue(cr.Filters(title="WIDGET").matches(self.session()))
        self.assertFalse(cr.Filters(title="nope").matches(self.session()))

    def test_dir_filter_matches_both_spellings(self):
        self.assertTrue(cr.Filters(directory="/home/u/proj").matches(self.session()))
        self.assertTrue(cr.Filters(directory="~/proj").matches(self.session()))
        self.assertTrue(cr.Filters(directory="ALPHA").matches(self.session()))

    def test_anywhere_matches_either_field(self):
        self.assertTrue(cr.Filters(anywhere="widget").matches(self.session()))
        self.assertTrue(cr.Filters(anywhere="alpha").matches(self.session()))
        self.assertFalse(cr.Filters(anywhere="zzz").matches(self.session()))

    def test_filters_combine_with_and(self):
        both = cr.Filters(title="widget", directory="alpha")
        self.assertTrue(both.matches(self.session()))
        self.assertFalse(cr.Filters(title="widget", directory="beta").matches(self.session()))

    def test_title_filter_does_not_match_the_directory(self):
        self.assertFalse(cr.Filters(title="alpha").matches(self.session()))

    def test_describe_lists_every_active_filter(self):
        self.assertEqual(cr.Filters().describe(), "")
        self.assertEqual(
            cr.Filters(anywhere="a", title="b", directory="c").describe(),
            'title/dir ~ "a", title ~ "b", dir ~ "c"',
        )


class LiveDetectionTest(unittest.TestCase):
    def fake_proc(self, processes):
        """Build a procfs-shaped tree: {pid: (argv, cwd)}. cwd=None omits the symlink.

        The cwd symlink is allowed to dangle — os.readlink reports its target either way, which is all
        discover_live reads.
        """
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        for pid, (argv, cwd) in processes.items():
            entry = Path(root.name) / str(pid)
            entry.mkdir()
            (entry / "cmdline").write_bytes(b"".join(a.encode() + b"\0" for a in argv))
            if cwd:
                (entry / "cwd").symlink_to(cwd)
        (Path(root.name) / "not-a-pid").mkdir()  # procfs holds non-pid entries too
        return root.name

    def test_bare_launch_is_bucketed_by_directory(self):
        proc = self.fake_proc({
            100: (["claude"], "/home/u/proj"),
            101: (["claude", "--model", "opus"], "/home/u/proj"),
            102: (["claude"], "/home/u/other"),
        })
        live = cr.discover_live(proc)
        self.assertEqual(live.sids, set())
        self.assertEqual(live.cwd_counts, cr.Counter({"/home/u/proj": 2, "/home/u/other": 1}))

    def test_process_without_a_readable_cwd_is_skipped(self):
        proc = self.fake_proc({100: (["claude"], None)})
        self.assertEqual(cr.discover_live(proc).cwd_counts, cr.Counter())

    def test_resume_flag_names_the_session_outright(self):
        proc = self.fake_proc({100: (["claude", "--resume", "sid-abc"], None)})
        live = cr.discover_live(proc)
        self.assertEqual(live.sids, {"sid-abc"})
        self.assertEqual(live.cwd_counts, cr.Counter())

    def test_resume_flag_is_found_after_other_flags(self):
        proc = self.fake_proc({100: (["claude", "--model", "opus", "--resume", "sid-xyz"], None)})
        self.assertEqual(cr.discover_live(proc).sids, {"sid-xyz"})

    def test_absolute_argv0_still_counts_as_claude(self):
        proc = self.fake_proc({100: (["/usr/local/bin/claude", "--resume", "sid-1"], None)})
        self.assertEqual(cr.discover_live(proc).sids, {"sid-1"})

    def test_other_processes_are_ignored(self):
        proc = self.fake_proc({100: (["python3", "claude", "--resume", "x"], None), 101: ([], None)})
        live = cr.discover_live(proc)
        self.assertEqual(live.sids, set())
        self.assertEqual(live.cwd_counts, cr.Counter())

    def test_missing_proc_root_degrades_quietly(self):
        live = cr.discover_live("/definitely/not/a/proc")
        self.assertEqual(live.sids, set())
        self.assertEqual(live.cwd_counts, cr.Counter())

    def sessions(self, *specs):
        return [cr.Session(sid=sid, cwd=cwd, mtime=mtime, status=status, home="/home/u")
                for sid, cwd, mtime, status in specs]

    def test_exact_sid_marks_live(self):
        sessions = self.sessions(("a", "/w", 2, "???"), ("b", "/w", 1, "???"))
        cr.assign_live(sessions, cr.LiveProcesses(sids={"b"}))
        self.assertEqual([s.status for s in sessions], ["???", "live"])

    def test_bare_launch_claims_the_newest_session_in_that_directory(self):
        sessions = self.sessions(("new", "/w", 3, "???"), ("old", "/w", 2, "???"), ("other", "/x", 1, "???"))
        cr.assign_live(sessions, cr.LiveProcesses(cwd_counts=cr.Counter({"/w": 1})))
        self.assertEqual([s.status for s in sessions], ["live", "???", "???"])

    def test_two_bare_launches_claim_two_sessions(self):
        sessions = self.sessions(("new", "/w", 3, "???"), ("mid", "/w", 2, "???"), ("old", "/w", 1, "???"))
        cr.assign_live(sessions, cr.LiveProcesses(cwd_counts=cr.Counter({"/w": 2})))
        self.assertEqual([s.status for s in sessions], ["live", "live", "???"])

    def test_bare_launch_skips_a_session_already_named_exactly(self):
        sessions = self.sessions(("new", "/w", 3, "???"), ("old", "/w", 2, "???"))
        cr.assign_live(sessions, cr.LiveProcesses(sids={"new"}, cwd_counts=cr.Counter({"/w": 1})))
        self.assertEqual([s.status for s in sessions], ["live", "live"])

    def test_sign_off_beats_live(self):
        sessions = self.sessions(("a", "/w", 1, "done"))
        cr.assign_live(sessions, cr.LiveProcesses(sids={"a"}))
        self.assertEqual(sessions[0].status, "done", "you finished but left the tab open")


class LayoutTest(unittest.TestCase):
    def test_widths_at_a_normal_terminal(self):
        layout = cr.Layout.for_width(140)
        self.assertEqual((layout.title, layout.directory, layout.branch), (36, 22, 24))
        self.assertEqual(sum(layout.cell_widths) + 1 + 3 * 7, 140, "row fills the terminal exactly")

    def test_narrow_terminals_clamp_to_minimums(self):
        layout = cr.Layout.for_width(40)
        self.assertEqual(layout.cols, cr.MIN_COLS)
        self.assertEqual((layout.title, layout.directory, layout.branch), (24, 16, 14))

    def test_wide_terminals_clamp_to_maximums(self):
        layout = cr.Layout.for_width(400)
        self.assertEqual((layout.title, layout.directory, layout.branch), (80, 60, 60))


class TrimAndMarkTest(unittest.TestCase):
    def test_trim_head_keeps_the_start(self):
        self.assertEqual(cr.trim_head("abcdef", 6), "abcdef")
        self.assertEqual(cr.trim_head("abcdef", 4), "abc…")

    def test_trim_tail_keeps_the_leaf(self):
        self.assertEqual(cr.trim_tail("/a/b/c", 6), "/a/b/c")
        self.assertEqual(cr.trim_tail("/a/b/c", 4), "…b/c")

    def test_mark_wraps_every_occurrence_case_insensitively(self):
        spans = cr.mark("Spark and spark", "SPARK")
        self.assertEqual([s.text for s in spans], ["Spark", " and ", "spark"])
        self.assertEqual([bool(s.on) for s in spans], [True, False, True])

    def test_mark_treats_metacharacters_literally(self):
        self.assertEqual([s.text for s in cr.mark("a*b", "*")], ["a", "*", "b"])
        self.assertEqual([s.text for s in cr.mark("plain", "[a-z]")], ["plain"])
        self.assertEqual([s.text for s in cr.mark("q?", "?")], ["q", "?"])

    def test_mark_without_a_needle_is_a_single_span(self):
        self.assertEqual([s.text for s in cr.mark("text", "")], ["text"])

    def test_marking_never_changes_the_visible_width(self):
        for needle in ("", "e", "*", "the"):
            self.assertEqual(cr.cell_width(cr.mark("the deploy race", needle)), len("the deploy race"), needle)


class RenderTest(unittest.TestCase):
    def sessions(self, count=4):
        return [
            cr.Session(sid=f"sid-{i}", cwd=f"/home/u/proj/p{i}", mtime=1_000_000 + i,
                       title=f"Session about spark number {i} with a fairly long title",
                       branch="adevore/DIRP-1/a-branch-name-that-is-long", messages=i * 3,
                       out_tokens=i * 90_000, status=["???", "done", "live", "tbc"][i % 4], home="/home/u")
            for i in range(count)
        ]

    def dividers(self, line):
        return [i for i, char in enumerate(strip(line)) if char == "│"]

    def test_every_row_shares_the_headers_column_positions(self):
        for cols in (90, 120, 140, 200, 400):
            layout = cr.Layout.for_width(cols)
            lines = cr.render_table(self.sessions(), layout, color=True)
            positions = {tuple(self.dividers(line)) for line in lines if "│" in line}
            self.assertEqual(len(positions), 1, f"columns drift at {cols} cols")

    def test_highlighting_does_not_move_any_column(self):
        layout = cr.Layout.for_width(140)
        plain = cr.render_table(self.sessions(), layout, color=True)
        marked = cr.render_table(self.sessions(), layout, highlight="spark", color=True)
        self.assertNotEqual(plain, marked, "highlight should change the output")
        self.assertEqual([self.dividers(line) for line in plain], [self.dividers(line) for line in marked])
        self.assertEqual([strip(line) for line in plain], [strip(line) for line in marked],
                         "highlighting adds escapes only, never visible characters")

    def test_striped_rows_reach_the_terminal_edge(self):
        layout = cr.Layout.for_width(140)
        lines = cr.render_table(self.sessions(6), layout, highlight="spark", color=True)
        for line in lines[2:]:  # skip header and rule
            self.assertEqual(len(strip(line)), 140)

    def test_colour_is_suppressed_when_not_a_terminal(self):
        lines = cr.render_table(self.sessions(), cr.Layout.for_width(140), highlight="spark", color=False)
        self.assertFalse(any("\x1b" in line for line in lines))

    def test_status_and_token_levels_are_coloured(self):
        lines = cr.render_table(self.sessions(4), cr.Layout.for_width(140), color=True)
        body = "".join(lines)
        self.assertIn(cr.STATUS_COLORS["done"], body)
        self.assertIn(cr.STATUS_COLORS["live"], body)
        self.assertIn(cr.TOKEN_COLORS["crit"], body)  # 3 * 90k = 270k
        self.assertIn(cr.TOKEN_COLORS["warn"], body)  # 2 * 90k = 180k


class ParseArgsTest(unittest.TestCase):
    def test_defaults(self):
        options = cr.parse_args([])
        self.assertEqual(options.count, cr.DEFAULT_COUNT)
        self.assertEqual(options.filters, cr.Filters())
        self.assertEqual(options.highlight, "")

    def test_every_filter_flag(self):
        options = cr.parse_args(["-f", "a", "-fs", "b", "-fd", "c", "-hl", "d"])
        self.assertEqual(options.filters, cr.Filters(anywhere="a", title="b", directory="c"))
        self.assertEqual(options.highlight, "d")

    def test_long_flag_spellings(self):
        options = cr.parse_args(["--find-session", "b", "--find-dir", "c", "--highlight", "d"])
        self.assertEqual(options.filters, cr.Filters(title="b", directory="c"))
        self.assertEqual(options.highlight, "d")

    def test_positional_is_shorthand_for_f(self):
        self.assertEqual(cr.parse_args(["spark"]).filters, cr.Filters(anywhere="spark"))

    def test_options_may_follow_the_positional(self):
        self.assertEqual(cr.parse_args(["spark", "-n", "40"]).count, 40)

    def test_two_search_strings_are_rejected(self):
        for argv in (["one", "two"], ["-f", "one", "two"]):
            with self.assertRaises(cr.UsageError) as caught:
                cr.parse_args(argv)
            self.assertIn("at most one search string", str(caught.exception))

    def test_count_must_be_a_positive_integer(self):
        for bad in ("0", "abc", "-1", ""):
            with self.assertRaises(cr.UsageError) as caught:
                cr.parse_args(["-n", bad])
            self.assertIn("positive integer", str(caught.exception))

    def test_count_with_no_value(self):
        with self.assertRaises(cr.UsageError):
            cr.parse_args(["-n"])

    def test_flags_need_values(self):
        for flag in ("-f", "-fs", "-fd", "-hl", "--find-dir"):
            with self.assertRaises(cr.UsageError) as caught:
                cr.parse_args([flag])
            self.assertIn("needs a search string", str(caught.exception))

    def test_unknown_option_asks_for_the_usage(self):
        with self.assertRaises(cr.UsageError) as caught:
            cr.parse_args(["--nope"])
        self.assertTrue(caught.exception.show_usage)
        self.assertIn('Invalid option: "--nope"', str(caught.exception))

    def test_help_is_not_an_error(self):
        for flag in ("-h", "--help"):
            with self.assertRaises(cr.HelpRequested):
                cr.parse_args([flag])

    def test_result_file_is_accepted(self):
        self.assertEqual(cr.parse_args(["--result-file", "/tmp/x"]).result_file, "/tmp/x")


class PromptTest(unittest.TestCase):
    def choose(self, typed, size=3):
        with contextlib.redirect_stderr(io.StringIO()) as err:
            choice = cr.prompt_choice(size, stdin=io.StringIO(typed), stderr=io.StringIO())
        return choice, err.getvalue()

    def test_valid_selection_is_zero_based(self):
        self.assertEqual(self.choose("2\n")[0], 1)

    def test_q_quits(self):
        self.assertIsNone(self.choose("q\n")[0])

    def test_end_of_input_quits_instead_of_spinning(self):
        # The shell implementation looped forever here, since `read` keeps failing at EOF.
        self.assertIsNone(self.choose("")[0])

    def test_out_of_range_and_junk_are_rejected_then_retried(self):
        choice, errors = self.choose("0\n9\nxyz\n3\n")
        self.assertEqual(choice, 2)
        self.assertEqual(errors.count("Enter a number between 1 and 3"), 3)

    def test_no_prompt_is_written_for_non_tty_input(self):
        written = io.StringIO()
        cr.prompt_choice(3, stdin=io.StringIO("1\n"), stderr=written)
        self.assertEqual(written.getvalue(), "", "bash's read -p only prompts a terminal; match that")


if __name__ == "__main__":
    unittest.main()
