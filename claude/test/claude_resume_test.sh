#!/bin/bash
# Tests for claude_resume: delegates the picker's unit tests to python (claude_resume_test.py), then
# exercises the shell wrapper end-to-end against a throwaway HOME with a fake `claude` on PATH — the
# wrapper's whole job is the cd + resume handoff, and only a shell can check that.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not available -> skipping claude_resume tests"; exit 0
fi

echo "--- picker unit tests (python) ---"
# Run from this directory so the test module (and the picker it loads by path) resolve.
if ! (cd "$DIR" && python3 -m unittest claude_resume_test 2>&1 | tail -4); then
  echo "✗ python unit tests failed"; exit 1
fi

echo "--- wrapper end-to-end ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A throwaway HOME holding two sessions: one in a directory that exists, one pointing at a directory
# that has since been deleted.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude/projects/proj" "$FAKE_HOME/work"
python3 - "$FAKE_HOME" <<'PY'
import json, os, sys
home = sys.argv[1]
projects = os.path.join(home, ".claude", "projects", "proj")


def write(sid, cwd, title, mtime):
    path = os.path.join(projects, f"{sid}.jsonl")
    with open(path, "w") as fh:
        fh.write(json.dumps({"type": "user", "cwd": cwd, "gitBranch": "master",
                             "message": {"role": "user", "content": title}}) + "\n")
        fh.write(json.dumps({"type": "last-prompt", "lastPrompt": "thanks"}) + "\n")
    os.utime(path, (mtime, mtime))


write("11111111-0000-4000-8000-000000000001", os.path.join(home, "work"), "session in a live directory", 2000)
write("22222222-0000-4000-8000-000000000002", os.path.join(home, "deleted"), "session in a deleted directory", 1000)
PY

# A stand-in for `claude` that records where it ran and what it was passed.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/claude" <<'FAKE'
#!/bin/bash
{ echo "cwd=$PWD"; echo "args=$*"; } > "$FAKE_CLAUDE_LOG"
FAKE
chmod +x "$TMP/bin/claude"

# Drive the wrapper in a subshell: fake HOME, fake claude first on PATH, answer piped to the prompt.
# Echoes the wrapper's own output, then the shell's final directory (proving the cd happened).
run_wrapper() {
  local answer="$1"; shift
  FAKE_CLAUDE_LOG="$TMP/claude.log" \
  HOME="$FAKE_HOME" PATH="$TMP/bin:$PATH" COLUMNS=140 DOTFILES="$ROOT" \
    bash -c '
      source "$DOTFILES/claude/functions/claude_resume.func"
      claude_resume "$@"
      echo "rc=$?"
      echo "final_pwd=$PWD"
    ' _ "$@" <<< "$answer" 2>&1
}

# 1. Help, with no session listing.
out="$(run_wrapper q -h)"
assert_contains "claude_resume - pick a recent Claude Code session" "$out" "-h prints the usage"
assert_contains "-fd, --find-dir <str>" "$out" "-h lists the search flags"
assert_contains "rc=0" "$out" "-h exits 0"

# 2. Listing renders both sessions, newest first.
out="$(run_wrapper q)"
assert_contains "Found 2 session(s)" "$out" "lists every session in the fake HOME"
assert_contains "session in a live directory" "$out" "shows the newest session's title"
assert_contains "rc=0" "$out" "quitting at the prompt exits 0"
assert_equals "" "$(cat "$TMP/claude.log" 2>/dev/null)" "quitting never launches claude"

# 3. Filters reach the picker.
out="$(run_wrapper q -fs deleted)"
assert_contains "Found 1 session(s) matching title ~ \"deleted\"" "$out" "-fs filters by title"
out="$(run_wrapper q -fd "$FAKE_HOME/work")"
assert_contains "Found 1 session(s) matching dir ~" "$out" "-fd filters by directory"
out="$(run_wrapper q -fs nothing-matches-this)"
assert_contains "No matching sessions found for title ~ \"nothing-matches-this\"" "$out" "no matches reports the filter"
assert_contains "rc=1" "$out" "no matches exits 1"

# 4. Bad usage.
out="$(run_wrapper q -n 0)"
assert_contains "[ERROR] -n needs a positive integer, got \"0\"" "$out" "-n rejects zero"
assert_contains "rc=1" "$out" "bad usage exits 1"
out="$(run_wrapper q --bogus)"
assert_contains "[ERROR] Invalid option: \"--bogus\"" "$out" "unknown flags are rejected"

# 5. The handoff: picking row 1 cds into the session's directory and resumes it there.
: > "$TMP/claude.log"
out="$(run_wrapper 1)"
assert_contains "[INFO] Resuming 11111111-0000-4000-8000-000000000001 in $FAKE_HOME/work" "$out" "reports the resume"
assert_contains "final_pwd=$FAKE_HOME/work" "$out" "the shell is left in the session's directory"
assert_equals "cwd=$FAKE_HOME/work" "$(sed -n 1p "$TMP/claude.log")" "claude runs in the session's directory"
assert_equals "args=--resume 11111111-0000-4000-8000-000000000001" "$(sed -n 2p "$TMP/claude.log")" \
  "claude is passed --resume <session id>"

# 6. A session whose directory is gone still resumes, from wherever you are.
: > "$TMP/claude.log"
out="$(run_wrapper 1 -fs deleted)"
assert_contains "[WARN] Directory '$FAKE_HOME/deleted' no longer exists" "$out" "warns about the missing directory"
assert_contains "final_pwd=$PWD" "$out" "the shell stays put when the directory is gone"

# 7. Selection is validated before anything is launched.
: > "$TMP/claude.log"
out="$(printf '99\nq\n' | FAKE_CLAUDE_LOG="$TMP/claude.log" HOME="$FAKE_HOME" PATH="$TMP/bin:$PATH" \
  COLUMNS=140 DOTFILES="$ROOT" bash -c 'source "$DOTFILES/claude/functions/claude_resume.func"; claude_resume; echo "rc=$?"' 2>&1)"
assert_contains "[ERROR] Enter a number between 1 and 2 (or q)" "$out" "out-of-range picks are rejected"
assert_contains "rc=0" "$out" "quitting after a bad pick exits 0"
assert_equals "" "$(cat "$TMP/claude.log")" "a rejected pick never launches claude"

# 8. -l lists and stops: no prompt, nothing resumed, and a pick waiting on stdin is left untouched.
: > "$TMP/claude.log"
out="$(run_wrapper 1 -l)"
assert_contains "Found 2 session(s)" "$out" "-l still lists sessions"
assert_contains "rc=0" "$out" "-l exits 0"
assert_equals "" "$(cat "$TMP/claude.log")" "-l never launches claude"
assert_contains "final_pwd=$PWD" "$out" "-l leaves the shell where it was"
out="$(run_wrapper 1 --list -fs deleted)"
assert_contains "Found 1 session(s) matching title ~ \"deleted\"" "$out" "--list composes with filters"

# 9. Piped output stays clean: no escapes, and the table is on stdout where grep can reach it.
piped="$(HOME="$FAKE_HOME" PATH="$TMP/bin:$PATH" COLUMNS=140 DOTFILES="$ROOT" \
  bash -c 'source "$DOTFILES/claude/functions/claude_resume.func"; claude_resume -l' 2>/dev/null | grep "live directory")"
assert_contains "session in a live directory" "$piped" "-l output survives a pipe to grep"
assert_equals "0" "$(printf '%s' "$piped" | grep -c $'\033')" "piped output carries no color escapes"

# 10. Stdin at EOF quits instead of looping forever (the shell implementation used to spin here).
# shellcheck disable=SC2016  # $DOTFILES is expanded by the inner shell, which gets it from the env above
out="$(FAKE_CLAUDE_LOG="$TMP/claude.log" HOME="$FAKE_HOME" PATH="$TMP/bin:$PATH" COLUMNS=140 DOTFILES="$ROOT" \
  timeout 20 bash -c 'source "$DOTFILES/claude/functions/claude_resume.func"; claude_resume < /dev/null; echo "rc=$?"' 2>&1)"
assert_contains "rc=0" "$out" "end of input quits cleanly"

echo "All claude_resume tests passed"
