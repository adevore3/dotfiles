#!/bin/bash
# Unit tests for the notify-lib helper functions: classify_urgency, snippet, last_assistant_text.
# Sources notify-lib.sh directly (HOME pointed at a temp dir so a real ~/.claude/secrets.env can't leak in).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

TMP="$(mktemp -d)"
HOME="$TMP" source "$DIR/../hooks/notify-lib.sh"

# --- classify_urgency ---
assert_equals "input" "$(classify_urgency 'Should I use Postgres?')" "trailing question -> input"
assert_equals "input" "$(classify_urgency 'Working on it now. <!-- needs-input -->')" "marker -> input"
assert_equals "input" "$(classify_urgency 'Let me know how to proceed.')" "decision cue -> input"
assert_equals "fyi"   "$(classify_urgency 'Started the migration; it is running now.')" "statement -> fyi"
assert_equals "fyi"   "$(classify_urgency '')" "empty -> fyi"

# --- snippet ---
out=$(snippet "$(printf 'hello\nworld <!-- needs-input -->')")
assert_equals "hello world" "$out" "snippet strips marker + collapses newlines + trims"

long=$(printf 'a%.0s' $(seq 1 250))
out=$(snippet "$long")
assert_equals "200" "$(printf '%s' "$out" | tr -cd 'a' | wc -c | tr -d ' ')" "snippet truncates body to 200 chars"
assert_contains "…" "$out" "snippet appends ellipsis when truncated"

# --- last_assistant_text ---
tfile="$TMP/t.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"hi"}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"first answer"}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"second answer?"}]}}' \
  > "$tfile"
assert_equals "second answer?" "$(TRANSCRIPT="$tfile" last_assistant_text)" "returns last assistant text block"
assert_equals "" "$(TRANSCRIPT="$TMP/nope.jsonl" last_assistant_text)" "missing transcript -> empty"

rm -rf "$TMP"
echo "All notify-lib unit tests passed."
