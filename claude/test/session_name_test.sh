#!/bin/bash
# Tests session-name.sh's directory rendering: $HOME collapses to ~, then the path trims to its last two
# components. The name feeds both the statusline and the Slack/ntfy label, so its shape is load-bearing.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
source "$ROOT/claude/hooks/session-name.sh"

FAKE_HOME="/home/testuser"

# No transcript and no session id, so the name comes from the fallback cwd alone -- no timestamp suffix.
# A subshell keeps the overridden HOME from leaking into the next case.
name_for() { ( HOME="$FAKE_HOME"; session_name "" "" "$1" ); }

# shellcheck disable=SC2088  # the literal string "~/dotfiles" is the expected output, not a path to expand
assert_equals "~/dotfiles" "$(name_for "$FAKE_HOME/dotfiles")" "one level under \$HOME keeps the ~"
assert_equals "~" "$(name_for "$FAKE_HOME")" "\$HOME itself is a lone ~"
assert_equals "tmp/slacktest" "$(name_for "$FAKE_HOME/tmp/slacktest")" "deeper under \$HOME trims to two components"
assert_equals "spark/spark-4.1-migration" \
  "$(name_for "$FAKE_HOME/dotfiles/indeed/workspace/spark/spark-4.1-migration")" "a deep tree keeps the last two"
assert_equals "tmp/proj" "$(name_for "/tmp/proj")" "a path outside \$HOME trims the same way"
assert_equals "/tmp" "$(name_for "/tmp")" "a single-component path stays whole"

# A sibling sharing the $HOME prefix must not be mangled into "~2" by a naive prefix strip.
assert_equals "testuser2/proj" "$(name_for "${FAKE_HOME}2/proj")" "a sibling of \$HOME keeps its real path"

# Falls back to $PWD when given nothing at all.
expected="$(basename "$(dirname "$PWD")")/$(basename "$PWD")"
assert_equals "$expected" "$( ( HOME="$FAKE_HOME"; session_name "" "" "" ) )" "no cwd at all falls back to \$PWD"

# The transcript path: start dir and start time both come out of the transcript, not the fallback.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
transcript="$TMP/sess.jsonl"
printf '%s\n' '{"cwd":"/home/testuser/tmp/slacktest","timestamp":"2026-07-29T08:10:00Z"}' > "$transcript"
got="$( ( HOME="$FAKE_HOME"; CLAUDE_SESSION_TZ="America/Los_Angeles" \
  session_name "$transcript" "" "/somewhere/else" ) )"
assert_equals "tmp/slacktest @ 2026-07-29_01:10_PDT" "$got" "the transcript's cwd and timestamp win over the fallback"

echo "All session-name tests passed"
