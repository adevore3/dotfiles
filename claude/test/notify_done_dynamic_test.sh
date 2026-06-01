#!/bin/bash
# Integration tests for the dynamic, urgency-aware notify-done (Stop hook). Uses the shared
# stub curl + a temp transcript referenced via transcript_path in the piped JSON.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
source "$DIR/notify_test_helpers.sh"
HOOKS="$DIR/../hooks"
SLACK_OK="https://hooks.slack.com/services/T/B/zzz"

mk_transcript() {  # $1 = assistant text -> echoes a transcript file path under $STUB_DIR
  local f="$STUB_DIR/t.jsonl"
  jq -nc --arg t "$1" '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:$t}]}}' > "$f"
  printf '%s' "$f"
}

# needs-input + Slack unconfigured -> ntfy with high priority
setup_stub
tf=$(mk_transcript "Which database should I use?")
echo '{"cwd":"/tmp/proj","session_id":"abc123","transcript_path":"'"$tf"'"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
log=$(cat "$CURL_LOG")
assert_contains "ntfy.sh/claude-test-topic" "$log" "needs-input posts to ntfy"
assert_contains "Priority: high" "$log" "needs-input -> ntfy high priority"
assert_contains "Which database should I use" "$log" "needs-input ntfy body carries the snippet text"
teardown_stub

# needs-input + Slack delivers -> Slack message leads with session identity (no "Needs your input" prose)
setup_stub
tf=$(mk_transcript "Should I deploy now?")
echo '{"cwd":"/tmp/proj","session_id":"abc123","transcript_path":"'"$tf"'"}' | \
  HOME="$STUB_DIR" SLACK_WEBHOOK_URL="$SLACK_OK" bash "$HOOKS/notify-done.sh"
assert_contains "proj · abc123" "$(cat "$CURL_LOG")" "needs-input -> Slack leads with session identity"
teardown_stub

# fyi -> ntfy low priority + session identity (no "Done in" prose)
setup_stub
tf=$(mk_transcript "Started the build; it is running now.")
echo '{"cwd":"/tmp/proj","session_id":"abc123","transcript_path":"'"$tf"'"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
log=$(cat "$CURL_LOG")
assert_contains "Priority: low" "$log" "fyi -> ntfy low priority"
assert_contains "proj · abc123" "$log" "fyi -> body leads with session identity"
teardown_stub

# marker forces needs-input even without a question mark
setup_stub
tf=$(mk_transcript "I have two viable approaches. <!-- needs-input -->")
echo '{"cwd":"/tmp/proj","session_id":"abc123","transcript_path":"'"$tf"'"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
log=$(cat "$CURL_LOG")
assert_contains "Priority: high" "$log" "marker -> needs-input high priority"
assert_equals "0" "$(grep -c 'needs-input' "$CURL_LOG")" "marker is stripped from the snippet"
teardown_stub

# missing transcript -> graceful FYI default, exit 0
setup_stub
echo '{"cwd":"/tmp/proj","session_id":"abc123","transcript_path":"/nonexistent/x.jsonl"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"; rc=$?
log=$(cat "$CURL_LOG")
assert_equals "0" "$rc" "missing transcript -> exit 0"
assert_contains "proj · abc123" "$log" "missing transcript -> graceful session identity"
assert_contains "Priority: low" "$log" "missing transcript -> low priority (fyi)"
teardown_stub

echo "All notify-done dynamic tests passed."
