#!/usr/bin/env python3
"""Session picker behind the `claude_resume` shell function (see claude_resume.func).

Lists recent Claude Code sessions newest-first as a width-adaptive table, prompts for one, and reports
the pick back to the shell — the shell has to do the `cd` itself, since a child process cannot move its
parent's working directory. That handoff is the only reason this isn't a standalone executable:

    python3 claude_resume.py --result-file FILE [OPTIONS] [filter]

On a pick, FILE gets two lines: the session id, then the absolute launch directory. FILE is left empty
when the user quits. Without --result-file those two lines go to stdout instead (handy when poking at
the script directly; the wrapper always passes one).

Everything a session displays is read out of its transcript rather than inferred from the project dir
name under ~/.claude/projects, whose `/`->`-` munging is lossy and cannot be reversed.

--clean is the one mode that writes to that tree: it deletes the sessions whose launch directory has
since been removed. It never reports a pick, so the wrapper just exits.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------------------------------
# Logging — mirrors bash/functions/log_utils.sh (same prefixes, same streams, same LOG_LEVEL gate) so
# messages from the shell wrapper and from here are indistinguishable. Only the two levels this script
# emits are here; the wrapper owns the [WARN] about a directory that has gone missing.
# ---------------------------------------------------------------------------------------------------

INFO, ERROR = 2, 4


def _log_level() -> int:
    raw = os.environ.get("LOG_LEVEL", "")
    return int(raw) if raw.isdigit() else INFO


def log_info(message: str) -> None:
    if _log_level() <= INFO:
        print(f"[INFO] {message}")


def log_error(message: str) -> None:
    if _log_level() <= ERROR:
        print(f"[ERROR] {message}", file=sys.stderr)


# ---------------------------------------------------------------------------------------------------
# Status heuristics
# ---------------------------------------------------------------------------------------------------

# A transcript carries no status flag, so infer one from the last prompt you typed:
#   "gone" - the launch directory no longer exists (a fact, not a guess); resume cannot cd there
#   "live" - open in a running `claude` process (from process info, not guessed — see discover_live)
#   "done" - reads as approval/thanks/sign-off, the work wrapped up
#   "tbc"  - reads as "to be continued" / paused mid-flight
#   "???"  - anything else (a task, a question, or too ambiguous to call)
# "gone" outranks the rest: whatever the prompt said, a missing directory is the thing worth seeing.
# STRONG_DONE_RE holds unambiguous closers that mean "done" at any length; DONE_RE holds weaker approval
# words that only count in a short message, since they often appear mid-task ("nice, now do X").
STRONG_DONE_RE = re.compile(
    r"\b(close (this|it)|resolved|lgtm|ship it|all set|that'?s all|we'?re done|done here|nailed it)\b",
    re.I,
)
DONE_RE = re.compile(
    r"\b(thanks|thank you|thx|ty|perfect|great|awesome|nice|looks (good|great)|"
    r"that works|works( now| great)?|done|excellent|beautiful|amazing)\b",
    re.I,
)
TBC_RE = re.compile(
    r"\b(to be continued|tbc|wip|continue (this |it )?(later|tomorrow|next time)|"
    r"pick (this|it) (back )?up (later|tomorrow|next time)|come back to (this|it)|"
    r"pause here|let'?s pause|stop(ping)? here|finish (this |it )?(later|tomorrow)|"
    r"resume (this |it )?(later|tomorrow)|more (on this )?later|pick up where we left off|"
    r"for now|next session)\b",
    re.I,
)

LONG_PROMPT = 80  # at or above this length a prompt reads as an ongoing task, not a sign-off


def classify_status(last_prompt: str) -> str:
    """Guess where a session left off from its last user prompt."""
    prompt = (last_prompt or "").strip()
    if not prompt:
        return "???"
    if STRONG_DONE_RE.search(prompt):
        return "done"
    if len(prompt) >= LONG_PROMPT:
        return "???"
    if TBC_RE.search(prompt):
        return "tbc"
    if DONE_RE.search(prompt):
        return "done"
    return "???"


# ---------------------------------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------------------------------

FIELD_CAP = 120  # generous safety cap; the table trims again to its adaptive column widths
WARN_TOKENS = 100_000
CRIT_TOKENS = 200_000


def abbreviate(path: str, home: str) -> str:
    """Replace a leading $HOME with '~'."""
    return path.replace(home, "~", 1) if home and path.startswith(home) else path


@dataclass
class Session:
    """One resumable session, as displayed in the table."""

    sid: str
    cwd: str  # absolute launch dir — what the shell cds to
    mtime: float
    title: str = ""
    branch: str = ""
    messages: int = 0
    out_tokens: int = 0
    status: str = "???"
    home: str = ""
    path: str = ""  # the transcript this was read from — what --clean deletes
    exists: bool = True  # is cwd still a directory? a stale session cannot be resumed in place
    live: bool = False  # open in a running process (see assign_live); never deleted by --clean

    @property
    def home_cwd(self) -> str:
        return abbreviate(self.cwd, self.home)

    def display_dir(self, width: int) -> str:
        return elide_path(self.cwd, self.home, width)

    @property
    def when(self) -> str:
        return datetime.fromtimestamp(self.mtime).strftime("%Y-%m-%d %H:%M")

    @property
    def token_cell(self) -> str:
        return f"{self.out_tokens / 1000:.0f}k" if self.out_tokens >= 1000 else str(self.out_tokens)

    @property
    def token_level(self) -> str:
        if self.out_tokens > CRIT_TOKENS:
            return "crit"
        if self.out_tokens > WARN_TOKENS:
            return "warn"
        return ""


def _first_text(content) -> str:
    """Pull displayable text out of a user message's content (string or block list)."""
    if isinstance(content, str):
        return content if content.strip() else ""
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text" and block.get("text", "").strip():
                return block["text"]
    return ""


def read_transcript(path: Path, home: str) -> Session | None:
    """Build a Session from one transcript in a single pass, or None if it has no cwd to resume into."""
    cwd = None
    first_user_text = ""
    ai_title = ""
    branch = ""
    last_prompt = ""
    messages = 0
    out_tokens = 0

    with open(path, errors="ignore") as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except (ValueError, TypeError):
                continue
            if not isinstance(entry, dict):
                continue
            kind = entry.get("type")
            # The FIRST cwd is the session launch dir: it determines which project dir stores the
            # transcript and where `claude --resume` looks for it. A mid-session `cd` changes later
            # cwd values but not the storage location.
            if cwd is None and entry.get("cwd"):
                cwd = entry["cwd"]
            if kind in ("user", "assistant"):
                messages += 1
            if kind == "user" and not first_user_text:
                first_user_text = _first_text((entry.get("message") or {}).get("content"))
            # Claude writes the auto-generated session name as repeated 'ai-title' entries; keep the last.
            if kind == "ai-title" and entry.get("aiTitle"):
                ai_title = entry["aiTitle"]
            # Output tokens (what Claude generated) are a rough measure of session size.
            if kind == "assistant":
                usage = (entry.get("message") or {}).get("usage") or {}
                out_tokens += usage.get("output_tokens", 0)
            if entry.get("gitBranch"):
                branch = entry["gitBranch"]
            if kind == "last-prompt" and entry.get("lastPrompt"):
                last_prompt = entry["lastPrompt"]

    if not cwd:
        return None
    exists = os.path.isdir(cwd)
    return Session(
        sid=path.name[: -len(".jsonl")],
        cwd=cwd,
        mtime=path.stat().st_mtime,
        title=" ".join((ai_title or first_user_text).split())[:FIELD_CAP],
        branch=branch[:FIELD_CAP],
        messages=messages,
        out_tokens=out_tokens,
        status=classify_status(last_prompt) if exists else "gone",
        home=home,
        path=str(path),
        exists=exists,
    )


def scan_sessions(projects_dir: Path, home: str) -> list[Session]:
    """Every resumable session under a ~/.claude/projects tree, newest first."""
    sessions = []
    for path in projects_dir.rglob("*.jsonl"):
        if "subagents" in path.parts:  # subagent transcripts aren't resumable sessions
            continue
        try:
            session = read_transcript(path, home)
        except OSError:
            continue
        if session:
            sessions.append(session)
    # sid breaks mtime ties so the order never depends on directory-walk order.
    sessions.sort(key=lambda s: (-s.mtime, s.sid))
    return sessions


# ---------------------------------------------------------------------------------------------------
# Live-session detection
# ---------------------------------------------------------------------------------------------------


@dataclass
class LiveProcesses:
    """What the process table says is open right now."""

    sids: set[str] = field(default_factory=set)  # exact ids, from `claude --resume <sid>`
    cwd_counts: Counter = field(default_factory=Counter)  # bare `claude` launches, per directory


def discover_live(proc_root: str = "/proc") -> LiveProcesses:
    """Find running `claude` processes by reading procfs. Empty on non-Linux (no /proc)."""
    live = LiveProcesses()
    try:
        entries = os.listdir(proc_root)
    except OSError:
        return live
    for pid in entries:
        if not pid.isdigit():
            continue
        try:
            with open(f"{proc_root}/{pid}/cmdline", "rb") as handle:
                argv = [a.decode(errors="replace") for a in handle.read().split(b"\0") if a]
            if not argv or os.path.basename(argv[0]) != "claude":
                continue
            # `claude --resume <sid>` names the session outright. A bare `claude` doesn't, so bucket it
            # by cwd and let assign_live claim the newest transcript(s) launched there. (Claude appends
            # and closes its transcript, so open file descriptors are no help.)
            if "--resume" in argv:
                index = argv.index("--resume")
                if index + 1 < len(argv):
                    live.sids.add(argv[index + 1])
                    continue
            live.cwd_counts[os.readlink(f"{proc_root}/{pid}/cwd")] += 1
        except OSError:
            continue  # process exited, or not ours to inspect
    return live


def assign_live(sessions: list[Session], live: LiveProcesses) -> None:
    """Mark sessions open in a running process as "live", in place.

    Two statuses outrank it in the display: a sign-off, since you may have finished but left the tab up,
    and "gone", since a missing directory is what you need to see. The `live` flag is still set either
    way — it is what keeps --clean from deleting a transcript out from under a running process.
    """
    live_sids = set(live.sids)
    # For each bare-launch cwd, claim the N newest transcripts launched there (N = processes sharing
    # that cwd), skipping any already named exactly. sessions is newest-first, so these are the freshest.
    for target, count in live.cwd_counts.items():
        claimed = 0
        for session in sessions:
            if claimed >= count:
                break
            if session.cwd == target and session.sid not in live_sids:
                live_sids.add(session.sid)
                claimed += 1
    for session in sessions:
        if session.sid in live_sids:
            session.live = True
            if session.status not in ("done", "gone"):
                session.status = "live"


# ---------------------------------------------------------------------------------------------------
# Filtering
# ---------------------------------------------------------------------------------------------------


@dataclass
class Filters:
    """Case-insensitive substring filters. Whatever is set must match (AND)."""

    anywhere: str = ""  # -f: title or directory
    title: str = ""  # -fs/--find-session
    directory: str = ""  # -fd/--find-dir

    def matches(self, session: Session) -> bool:
        title = session.title.lower()
        # Both spellings of the directory, so `-fd ~/dotfiles` and `-fd /home/me/dotfiles` both hit.
        directory = f"{session.cwd}\n{session.home_cwd}".lower()
        if self.directory and self.directory.lower() not in directory:
            return False
        if self.title and self.title.lower() not in title:
            return False
        if self.anywhere:
            needle = self.anywhere.lower()
            if needle not in title and needle not in directory:
                return False
        return True

    def describe(self) -> str:
        """Human-readable summary for the header and the not-found message."""
        parts = []
        if self.anywhere:
            parts.append(f'title/dir ~ "{self.anywhere}"')
        if self.title:
            parts.append(f'title ~ "{self.title}"')
        if self.directory:
            parts.append(f'dir ~ "{self.directory}"')
        return ", ".join(parts)


# ---------------------------------------------------------------------------------------------------
# Table rendering
# ---------------------------------------------------------------------------------------------------

RESET = "\033[0m"
BOLD = "\033[1m"
ZEBRA = "\033[48;5;236m"  # subtle background for alternating rows
FG_DEFAULT = "\033[39m"  # restores the default foreground without clearing the zebra background
STATUS_COLORS = {
    "live": "\033[38;5;51m",
    "done": "\033[38;5;40m",
    "tbc": "\033[38;5;226m",
    "gone": "\033[38;5;244m",  # grey: still selectable, just not resumable in place
}
TOKEN_COLORS = {"crit": "\033[38;5;196m", "warn": "\033[38;5;208m"}
HIGHLIGHT_ON = "\033[1;38;5;207m"  # bold magenta
HIGHLIGHT_OFF = "\033[22;39m"  # bold off + default fg, so the zebra background survives
ELLIPSIS = "…"
MIN_COLS = 90
DEFAULT_COLS = 120


@dataclass(frozen=True)
class Span:
    """A run of visible text plus the escapes wrapping it. Width is always len(text)."""

    text: str
    on: str = ""
    off: str = ""

    def render(self, color: bool) -> str:
        return f"{self.on}{self.text}{self.off}" if color and self.on else self.text


Cell = list  # list[Span]


def trim_head(text: str, width: int) -> str:
    """Keep the start of a value, marking the cut with an ellipsis."""
    return text if len(text) <= width else text[: width - 1] + ELLIPSIS


def trim_tail(text: str, width: int) -> str:
    """Keep the end of a value (for paths, where the leaf matters most)."""
    return text if len(text) <= width else ELLIPSIS + text[len(text) - width + 1 :]


def elide_path(path: str, home: str, width: int) -> str:
    """Fit a path into width, dropping whole leading components before ever cutting mid-name.

    A path that fits is shown whole, leading '~' included — the '…/' prefix appears only when something
    really was dropped. Falls back to a character cut when even the last component is too wide.
    """
    text = abbreviate(path, home)
    if len(text) <= width:
        return text
    parts = [p for p in text.split("/") if p]
    for start in range(1, len(parts)):
        candidate = ELLIPSIS + "/" + "/".join(parts[start:])
        if len(candidate) <= width:
            return candidate
    return trim_tail(text, width)


def mark(text: str, needle: str) -> Cell:
    """Split text into spans, wrapping each case-insensitive occurrence of needle in highlight escapes.

    Substring matching, not glob or regex — '*' and '[a-z]' are literal.
    """
    if not needle:
        return [Span(text)]
    spans: Cell = []
    haystack, target = text.lower(), needle.lower()
    position = 0
    while True:
        hit = haystack.find(target, position)
        if hit < 0:
            break
        if hit > position:
            spans.append(Span(text[position:hit]))
        spans.append(Span(text[hit : hit + len(needle)], HIGHLIGHT_ON, HIGHLIGHT_OFF))
        position = hit + len(needle)
    if position < len(text):
        spans.append(Span(text[position:]))
    return spans


def cell_width(cell: Cell) -> int:
    return sum(len(span.text) for span in cell)


def pad(cell: Cell, width: int, right_align: bool = False) -> Cell:
    """Pad a cell to width with plain spaces — the escapes inside it never affect the count."""
    filler = " " * max(0, width - cell_width(cell))
    if not filler:
        return cell
    return [Span(filler)] + list(cell) if right_align else list(cell) + [Span(filler)]


@dataclass(frozen=True)
class Layout:
    """Column widths for a given terminal width."""

    cols: int
    title: int
    directory: int
    branch: int

    # Fixed columns are #:3 when:16 status:6 msgs:5 tokens:6; with the eight ' │ '/' ' separators that
    # leaves OVERHEAD, and the rest is shared by the three flexible columns.
    OVERHEAD = 58

    @classmethod
    def for_width(cls, cols: int) -> Layout:
        cols = max(cols, MIN_COLS)  # a tiny window still gets a usable layout
        flex = cols - cls.OVERHEAD
        title = min(max(flex * 45 // 100, 24), 80)
        directory = min(max(flex * 27 // 100, 16), 60)
        branch = min(max(flex - (flex * 45 // 100) - (flex * 27 // 100), 14), 60)
        return cls(cols=cols, title=title, directory=directory, branch=branch)

    @property
    def cell_widths(self) -> list[int]:
        return [3, 16, 6, self.title, self.directory, self.branch, 5, 6]


def render_line(cells: list[Cell], color: bool, zebra: bool, cols: int) -> str:
    """Join cells with ' │ ' dividers, optionally striping the row to the full terminal width."""
    body = " " + " │ ".join("".join(span.render(color) for span in cell) for cell in cells)
    if not color:
        return body
    if zebra:
        width = 1 + sum(cell_width(cell) for cell in cells) + 3 * (len(cells) - 1)
        return f"{ZEBRA}{body}{' ' * max(0, cols - width)}{RESET}"
    return f"{body}{RESET}"


def render_table(sessions: list[Session], layout: Layout, highlight: str = "", color: bool = True) -> list[str]:
    """The whole table: header, rule, one line per session."""
    headers = ["#", "When", "Status", "Title", "Directory", "Branch", "Msgs", "Tokens"]
    right = {0, 6, 7}  # #, Msgs and Tokens are right-aligned
    header_cells = [
        pad([Span(text)], width, i in right) for i, (text, width) in enumerate(zip(headers, layout.cell_widths))
    ]
    header = " " + " │ ".join("".join(span.text for span in cell) for cell in header_cells)
    lines = [f"{BOLD}{header}{RESET}" if color else header]

    # Rule segments are each column plus its surrounding spaces: two for every column but the last,
    # which has no trailing space because the row ends there.
    segments = [width + 2 for width in layout.cell_widths]
    segments[-1] -= 1
    lines.append("┼".join("─" * width for width in segments))

    for index, session in enumerate(sessions):
        status_color = STATUS_COLORS.get(session.status, "")
        token_color = TOKEN_COLORS.get(session.token_level, "")
        # The colored cells pad *inside* their escapes; padding is spaces either way, and it keeps the
        # emitted bytes identical to what the shell implementation produced.
        cells = [
            pad([Span(str(index + 1))], 3, right_align=True),
            pad([Span(session.when)], 16),
            [Span(session.status.ljust(6), status_color, FG_DEFAULT if status_color else "")],
            pad(mark(trim_head(session.title, layout.title), highlight), layout.title),
            pad(mark(session.display_dir(layout.directory), highlight), layout.directory),
            pad([Span(trim_head(session.branch, layout.branch))], layout.branch),
            pad([Span(str(session.messages))], 5, right_align=True),
            [Span(session.token_cell.rjust(6), token_color, FG_DEFAULT if token_color else "")],
        ]
        lines.append(render_line(cells, color, zebra=index % 2 == 1, cols=layout.cols))
    return lines


# ---------------------------------------------------------------------------------------------------
# Selection prompt
# ---------------------------------------------------------------------------------------------------


def prompt_choice(size: int, stdin=None, stderr=None) -> int | None:
    """Ask which row to resume. Returns a 0-based index, or None to quit (q or end of input).

    The prompt goes to stderr and only when stdin is a terminal, matching bash's `read -p`.
    """
    stdin = stdin or sys.stdin
    stderr = stderr or sys.stderr
    prompt = f"Session to resume (1-{size}, q to quit): "
    while True:
        if stdin.isatty():
            stderr.write(prompt)
            stderr.flush()
        answer = stdin.readline()
        if not answer:  # end of input — nothing to pick, so quit rather than spin
            if stdin.isatty():
                stderr.write("\n")
            return None
        answer = answer.strip()
        if answer == "q":
            return None
        if answer.isdigit() and 1 <= int(answer) <= size:
            return int(answer) - 1
        log_error(f"Enter a number between 1 and {size} (or q)")


def prompt_confirm(question: str, stdin=None, stderr=None) -> bool:
    """Ask once before deleting. Only "y"/"yes" proceeds; anything else, including EOF, aborts."""
    stdin = stdin or sys.stdin
    stderr = stderr or sys.stderr
    if stdin.isatty():
        stderr.write(f"{question} (y/N): ")
        stderr.flush()
    answer = stdin.readline()
    if not answer:
        if stdin.isatty():
            stderr.write("\n")
        return False
    return answer.strip().lower() in ("y", "yes")


# ---------------------------------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------------------------------


def remove_session_files(session: Session) -> tuple[list[str], list[str]]:
    """Delete one session's transcript and its '<sid>/' sidecar dir (tool-results, subagents).

    Returns (removed paths, error messages) rather than raising: one unreadable session should not
    abandon the rest of the sweep.
    """
    transcript = Path(session.path)
    removed: list[str] = []
    errors: list[str] = []
    for target in (transcript, transcript.parent / session.sid):
        try:
            if target.is_symlink() or target.is_file():
                target.unlink()
            elif target.is_dir():
                shutil.rmtree(target)
            else:
                continue
            removed.append(str(target))
        except OSError as error:
            errors.append(f"{target}: {error}")
    return removed, errors


def has_transcript(directory: Path) -> bool:
    """Is any transcript left under a project dir? os.walk does not follow symlinks, so a 'memory'
    symlink pointing into the dotfiles repo is never descended into."""
    for _, _, files in os.walk(directory):
        if any(name.endswith(".jsonl") for name in files):
            return True
    return False


def prune_project_dir(directory: Path) -> bool:
    """Remove a project dir once no transcripts remain under it. False if any are left.

    rmtree unlinks the 'memory' symlink some project dirs carry instead of following it, so the linked-to
    memory files in the dotfiles repo survive.
    """
    if has_transcript(directory):
        return False
    shutil.rmtree(directory)
    return True


def delete_sessions(stale: list[Session], projects: Path) -> int:
    """Delete every stale session, then prune the project dirs left without a transcript. 1 on error."""
    errors: list[str] = []
    deleted = 0
    for session in stale:
        removed, failed = remove_session_files(session)
        errors.extend(failed)
        if removed:
            deleted += 1
    for directory in sorted({Path(s.path).parent for s in stale}):
        if directory == projects:  # a transcript sitting in the root is not a project dir to prune
            continue
        try:
            if prune_project_dir(directory):
                log_info(f"Removed emptied project dir {directory}")
        except OSError as error:
            errors.append(f"{directory}: {error}")
    log_info(f"Deleted {deleted} session(s)")
    for message in errors:
        log_error(f"Could not remove {message}")
    return 1 if errors else 0


def run_clean(sessions: list[Session], layout: Layout, options: Options, projects: Path) -> int:
    """--clean: list the sessions whose launch directory is gone, then delete them on confirmation.

    Filters still apply, so a sweep can be narrowed with -fd. -n does not: capping a cleanup would
    silently leave stale sessions behind.
    """
    described = options.filters.describe()
    suffix = f" matching {described}" if described else ""
    stale = [s for s in sessions if not s.exists and not s.live]
    if not stale:
        log_info(f"No stale sessions{suffix} — nothing to clean")
        return 0

    log_info(f"{len(stale)} session(s){suffix} whose launch directory no longer exists:")
    print()
    for line in render_table(stale, layout, options.highlight, color=sys.stdout.isatty()):
        print(line)
    print()

    if options.list_only:
        return 0
    if not prompt_confirm(f"Delete these {len(stale)} session(s) and their transcripts?"):
        log_info("Nothing deleted")
        return 0
    return delete_sessions(stale, projects)


# ---------------------------------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------------------------------

USAGE = """
NAME:
  claude_resume - pick a recent Claude Code session, cd to its directory, and resume it

SYNOPSIS
  claude_resume [OPTIONS] [filter]

OPTIONS:
  -n <count>                  Number of recent sessions to list (default 25)
  -f <str>                    Match <str> against the session title OR its directory
  -fs, --find-session <str>   Match <str> against the session title only
  -fd, --find-dir <str>       Match <str> against the session directory only
  -hl, --highlight <str>      Mark <str> in the title/directory cells; filters nothing
  -l, --list                  Print the table and stop — no prompt, nothing resumed
  -c, --clean                 List the sessions whose launch directory is gone ("gone" in the table),
                              then delete them after a y/N confirmation. Deletes each transcript and
                              its '<session-id>/' sidecar dir, plus any project dir left without a
                              transcript. Filters apply; -n does not. Add -l for a dry run.
  -h, --help                  Prints this message

  Searches are case-insensitive substrings; multiple filter flags must all match.

EXAMPLES:
  claude_resume
  claude_resume spark
  claude_resume -n 40
  claude_resume -fd dotfiles
  claude_resume -fs statusline -fd dotfiles
  claude_resume -n 60 -hl iceberg
  claude_resume -l -n 50 | grep spark
  claude_resume --clean --list          # show what --clean would delete, delete nothing
  claude_resume --clean -fd /tmp        # sweep only stale sessions launched under /tmp
"""

DEFAULT_COUNT = 25


class UsageError(Exception):
    """Bad command line. Message is already caller-ready; show_usage asks for the help text too."""

    def __init__(self, message: str, show_usage: bool = False):
        super().__init__(message)
        self.show_usage = show_usage


class HelpRequested(Exception):
    """-h/--help: not an error, just print the usage and stop."""


@dataclass
class Options:
    count: int = DEFAULT_COUNT
    filters: Filters = field(default_factory=Filters)
    highlight: str = ""
    list_only: bool = False  # -l: render and stop, so the table can be read or piped
    clean: bool = False  # -c: delete the sessions whose launch dir is gone, instead of resuming one
    result_file: str = ""


def parse_args(argv: list[str]) -> Options:
    """Hand-rolled so `-fs`/`-fd`/`-hl` keep working (argparse reads -fs as -f s) and so the error
    messages match the wrapper's log_error style. Options may appear before or after the filter."""
    options = Options()
    filters = options.filters
    positional: list[str] = []
    index = 0

    def value_for(flag: str) -> str:
        nonlocal index
        if index + 1 >= len(argv):
            raise UsageError(f"{flag} needs a search string")
        index += 1
        return argv[index]

    while index < len(argv):
        arg = argv[index]
        if arg in ("-h", "--help"):
            raise HelpRequested()
        elif arg == "-n":
            if index + 1 >= len(argv) or not re.fullmatch(r"[1-9][0-9]*", argv[index + 1]):
                got = argv[index + 1] if index + 1 < len(argv) else ""
                raise UsageError(f'-n needs a positive integer, got "{got}"')
            index += 1
            options.count = int(argv[index])
        elif arg == "-f":
            filters.anywhere = value_for(arg)
        elif arg in ("-fs", "--find-session"):
            filters.title = value_for(arg)
        elif arg in ("-fd", "--find-dir"):
            filters.directory = value_for(arg)
        elif arg in ("-hl", "--highlight"):
            options.highlight = value_for(arg)
        elif arg in ("-l", "--list"):
            options.list_only = True
        elif arg in ("-c", "--clean"):
            options.clean = True
        elif arg == "--result-file":  # internal: where to report the pick back to the shell wrapper
            options.result_file = value_for(arg)
        elif arg.startswith("-"):
            raise UsageError(f'Invalid option: "{arg}"', show_usage=True)
        else:
            positional.append(arg)
        index += 1

    # A bare positional argument is shorthand for -f; more than one, or one alongside -f, is ambiguous —
    # say so rather than silently dropping any of them.
    if positional:
        if len(positional) > 1 or filters.anywhere:
            raise UsageError("Pass at most one search string, either positionally or with -f")
        filters.anywhere = positional[0]
    return options


def terminal_width() -> int:
    """Terminal columns: $COLUMNS (bash keeps it current) wins, then an ioctl, then a sane default."""
    columns = os.environ.get("COLUMNS", "")
    if columns.isdigit():
        return int(columns)
    return shutil.get_terminal_size((DEFAULT_COLS, 24)).columns


# ---------------------------------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        options = parse_args(argv)
    except HelpRequested:
        print(USAGE)
        return 0
    except UsageError as error:
        log_error(str(error))
        if error.show_usage:
            print(USAGE)
        return 1

    if not shutil.which("claude"):
        log_error("'claude' not found on PATH")
        return 1

    home = os.path.expanduser("~")
    projects = Path(home) / ".claude" / "projects"
    if not projects.is_dir():
        log_error(f"No Claude projects dir at {projects}")
        return 1

    sessions = [s for s in scan_sessions(projects, home) if options.filters.matches(s)]
    # Live detection runs across every match, then the list is capped: a bare `claude` claims the
    # newest transcript from its directory whether or not that row made the cut.
    assign_live(sessions, discover_live())
    layout = Layout.for_width(terminal_width())

    if options.clean:
        return run_clean(sessions, layout, options, projects)

    if not sessions:
        described = options.filters.describe()
        log_error("No matching sessions found" + (f" for {described}" if described else ""))
        return 1

    sessions = sessions[: options.count]
    described = options.filters.describe()
    log_info(
        f"Found {len(sessions)} session(s)"
        + (f" matching {described}" if described else "")
        + (f', highlighting "{options.highlight}"' if options.highlight else "")
        + f" (most recent first, {layout.cols}-col terminal):"
    )
    print()
    for line in render_table(sessions, layout, options.highlight, color=sys.stdout.isatty()):
        print(line)
    print()

    if options.list_only:
        return 0

    choice = prompt_choice(len(sessions))
    if choice is None:
        return 0

    picked = sessions[choice]
    report = f"{picked.sid}\n{picked.cwd}\n"
    if options.result_file:
        with open(options.result_file, "w") as handle:
            handle.write(report)
    else:
        sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(file=sys.stderr)  # finish the prompt line the way a shell read would
        sys.exit(130)
