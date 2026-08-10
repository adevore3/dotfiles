#!/bin/bash
# Tests session-title.sh: the UserPromptSubmit hook that titles a session after the Jira ticket being worked on.
# Verifies prompt-first detection, the branch/dir fallback, asking instead of guessing when two keys collide or a new
# key appears mid-session, answering a pending question by full key or bare number, remembering declines, the ask cap,
# and the permanent back-off once the session has been renamed by hand. Uses temp state/cache dirs and an unreadable
# netrc, so nothing here touches the real ~/.claude state or the network.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
HOOK="$DIR/../hooks/session-title.sh"

assert_empty() {
  if [[ -z "$1" ]]; then echo "✓ $2"; else echo "✗ $2"; echo "  Expected no output, got: $1"; exit 1; fi
}

new_env() {
  BASE="$(mktemp -d)"
  STATE="$BASE/state"; CACHE="$BASE/cache"
  mkdir -p "$STATE" "$CACHE"
  # Points at a path that does not exist, so jira_summary returns early and titles stay bare keys unless seeded.
  NETRC="$BASE/nope.netrc"
}

seed_summary() { printf '%s' "$2" >"$CACHE/$1"; }

run() {  # run <session_id> <current_title> <cwd> <prompt>
  jq -n --arg s "$1" --arg t "$2" --arg c "$3" --arg p "$4" \
    '{session_id:$s, session_title:$t, cwd:$c, hook_event_name:"UserPromptSubmit", prompt:$p}' |
    CLAUDE_SESSION_TITLE_STATE="$STATE" CLAUDE_SESSION_TITLE_CACHE="$CACHE" \
    CLAUDE_SESSION_TITLE_NETRC="$NETRC" CLAUDE_SESSION_TITLE_MAX_ASKS="${ASKS:-2}" \
    bash "$HOOK"
}

title_of() { printf '%s' "$1" | jq -r '.hookSpecificOutput.sessionTitle // empty'; }
ask_of()   { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# --- prompt is the primary signal ------------------------------------------------------------------------------

new_env
seed_summary DIRP-4683 "remove force_migrate option"
out=$(run s1 "" /tmp 'read jira ticket DIRP-4683 and implement it')
assert_equals "DIRP-4683 remove force_migrate option" "$(title_of "$out")" "single key in prompt sets the title"

new_env
out=$(run s1 "" /tmp 'can you review the MRs for any comments')
assert_empty "$out" "no ticket anywhere stays silent"

new_env
out=$(run s1 "" /tmp 'the summary is DIRP-4683 but see also DIRP-4698')
assert_contains "DIRP-4683, DIRP-4698" "$(ask_of "$out")" "two keys with no title asks instead of guessing"
assert_empty "$(title_of "$out")" "the ambiguous case sets no title"

# --- branch / directory fallback -------------------------------------------------------------------------------

new_env
WT="$BASE/spark-hivesupport-DIRP-4689"; mkdir -p "$WT"
out=$(run s1 "" "$WT" 'continue where we left off')
assert_equals "DIRP-4689" "$(title_of "$out")" "no key in prompt falls back to the directory name"

new_env
REPO="$BASE/repo"; mkdir -p "$REPO"
git -C "$REPO" init -q 2>/dev/null
git -C "$REPO" checkout -q -b adevore/DIRP-4676/some-work 2>/dev/null
out=$(run s1 "" "$REPO" 'keep going')
assert_equals "DIRP-4676" "$(title_of "$out")" "no key in prompt falls back to the branch"

# The fallback only seeds an untitled session; it must not fight a title that is already set.
new_env
WT="$BASE/repo-DIRP-4689"; mkdir -p "$WT"
run s1 "" /tmp 'working on DIRP-4683' >/dev/null
out=$(run s1 "DIRP-4683" "$WT" 'no ticket in this one')
assert_empty "$out" "branch fallback does not override an existing title"

# --- answering a pending question ------------------------------------------------------------------------------

new_env
seed_summary DIRP-4698 "drop the deprecated arg"
run s1 "" /tmp 'DIRP-4683 and DIRP-4698 both' >/dev/null
out=$(run s1 "" /tmp 'DIRP-4698')
assert_equals "DIRP-4698 drop the deprecated arg" "$(title_of "$out")" "pending question answered by full key"
assert_contains "DIRP-4683" "$(jq -r '.declined | join(",")' "$STATE/s1.json")" "the key not chosen is recorded as declined"

new_env
run s1 "" /tmp 'DIRP-4683 and DIRP-4698 both' >/dev/null
out=$(run s1 "" /tmp '4698')
assert_equals "DIRP-4698" "$(title_of "$out")" "pending question answered by bare number"

new_env
run s1 "" /tmp 'DIRP-4683 and DIRP-4698 both' >/dev/null
out=$(run s1 "" /tmp 'never mind, what does the build do')
assert_empty "$out" "an unanswered question is dropped rather than re-asked"
assert_equals "" "$(jq -r '.pending | join(",")' "$STATE/s1.json")" "dropping the question clears pending"

# --- switching tickets mid-session -----------------------------------------------------------------------------

new_env
run s1 "" /tmp 'start on DIRP-4683' >/dev/null
out=$(run s1 "DIRP-4683" /tmp 'ok now lets do DIRP-4698')
assert_contains "DIRP-4698" "$(ask_of "$out")" "a new key after a title is set asks switch-or-citation"

new_env
run s1 "" /tmp 'start on DIRP-4683' >/dev/null
out=$(run s1 "DIRP-4683" /tmp 'more work on DIRP-4683 please')
assert_empty "$out" "re-mentioning the current ticket says nothing"

new_env
run s1 "" /tmp 'DIRP-4683 and DIRP-4698 both' >/dev/null
run s1 "" /tmp 'DIRP-4698' >/dev/null
out=$(run s1 "DIRP-4698" /tmp 'as I noted in DIRP-4683 earlier')
assert_empty "$out" "a declined key never asks again"

ASKS=1
new_env
run s1 "" /tmp 'DIRP-4683 and DIRP-4698' >/dev/null
out=$(run s1 "" /tmp 'and DIRP-4676 and DIRP-4667 too')
assert_empty "$out" "the ask cap stops it nagging"
unset ASKS

# --- manual rename wins permanently ----------------------------------------------------------------------------

new_env
run s1 "" /tmp 'start on DIRP-4683' >/dev/null
out=$(run s1 "force skipper migrate clean up" /tmp 'anything on DIRP-4689')
assert_empty "$out" "a hand-set title is not overwritten"
assert_equals "true" "$(jq -r .override "$STATE/s1.json")" "the hand-set title records a permanent override"
out=$(run s1 "force skipper migrate clean up" /tmp 'now DIRP-4667 please')
assert_empty "$out" "back-off survives later prompts"

# A session renamed before the hook ever fired has no set_title to compare against, and must still be left alone.
new_env
out=$(run s1 "my own name" /tmp 'work on DIRP-4683')
assert_empty "$out" "a title set before the hook ever ran is left alone"

# --- robustness -------------------------------------------------------------------------------------------------

new_env
out=$(run s1 "" /tmp 'multi
line "quoted" prompt with a $dollar and DIRP-4683 in it')
assert_equals "DIRP-4683" "$(title_of "$out")" "newlines, quotes and dollars in the prompt survive"

new_env
out=$(printf 'not json' | CLAUDE_SESSION_TITLE_STATE="$STATE" CLAUDE_SESSION_TITLE_CACHE="$CACHE" \
  CLAUDE_SESSION_TITLE_NETRC="$NETRC" bash "$HOOK")
assert_empty "$out" "malformed input is ignored rather than breaking the prompt"

new_env
seed_summary DIRP-4683 "$(printf 'x%.0s' {1..200})"
out=$(run s1 "" /tmp 'DIRP-4683')
long=$(title_of "$out"); len=${#long}
[[ "$len" -le 70 ]] && echo "✓ a long summary is truncated to the title cap" ||
  { echo "✗ a long summary is truncated to the title cap"; echo "  Got length $len"; exit 1; }

echo "All session-title tests passed"
