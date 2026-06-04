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

# --- chunk_text ---
# Short text -> single chunk, identical to input (no \x1f separators).
out=$(chunk_text "$(printf 'line one\nline two')" 2900)
assert_equals "$(printf 'line one\nline two')" "$out" "chunk_text keeps short text as one chunk"
assert_equals "0" "$(printf '%s' "$out" | tr -cd '\037' | wc -c | tr -d ' ')" "short text has no chunk separators"

# Long text -> multiple chunks, each <= max; chunks are separated by a single \x1f byte.
long=$(printf 'p%s\n' $(seq 1 50) | awk '{for(i=0;i<60;i++)printf $0" "; print ""}')
chunks=$(chunk_text "$long" 500)
nsep=$(printf '%s' "$chunks" | tr -cd '\037' | wc -c | tr -d ' ')
if [ "$nsep" -ge 1 ]; then echo "✓ long text splits into $((nsep + 1)) chunks"; else echo "✗ long text did not split"; exit 1; fi
maxlen=$(printf '%s' "$chunks" | awk 'BEGIN{RS="\037"; m=0} {if(length>m)m=length} END{print m}')
if [ "$maxlen" -le 500 ]; then echo "✓ every chunk <= max (longest $maxlen)"; else echo "✗ a chunk exceeded max ($maxlen)"; exit 1; fi

# A single line longer than max is hard-split rather than dropped.
oneline=$(printf 'x%.0s' $(seq 1 1200))
maxlen=$(chunk_text "$oneline" 500 | awk 'BEGIN{RS="\037"; m=0} {if(length>m)m=length} END{print m}')
if [ "$maxlen" -le 500 ]; then echo "✓ over-long single line hard-split (longest $maxlen)"; else echo "✗ long line not split ($maxlen)"; exit 1; fi

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
