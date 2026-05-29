#!/bin/bash
# Tests notify-session-start: notifies both channels, warns (stderr + cross-report) on failure,
# and never blocks (always exits 0). Uses the shared stub curl + temp HOME.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
source "$DIR/notify_test_helpers.sh"
HOOKS="$DIR/../hooks"
SLACK_OK="https://hooks.slack.com/services/T/B/zzz"

# Both configured + deliver -> both posted, exit 0, no warning
setup_stub
err="$STUB_DIR/err"
echo '{"cwd":"/tmp/proj","session_id":"sess01"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="$SLACK_OK" \
  bash "$HOOKS/notify-session-start.sh" 2>"$err"; rc=$?
assert_equals "0" "$rc" "session-start exits 0 when both deliver"
assert_contains "$SLACK_OK" "$(cat "$CURL_LOG")" "session-start posts to Slack"
assert_contains "ntfy.sh/claude-test-topic" "$(cat "$CURL_LOG")" "session-start posts to ntfy"
assert_equals "" "$(cat "$err")" "no warnings when both deliver"
teardown_stub

# ntfy configured but FAILS, Slack ok -> exit 0, stderr warns, cross-report via Slack
setup_stub
err="$STUB_DIR/err"
echo '{"cwd":"/tmp/proj","session_id":"sess01"}' | \
  HOME="$STUB_DIR" FAIL_NTFY=1 NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="$SLACK_OK" \
  bash "$HOOKS/notify-session-start.sh" 2>"$err"; rc=$?
assert_equals "0" "$rc" "session-start exits 0 even when ntfy fails"
assert_contains "ntfy delivery failed" "$(cat "$err")" "warning printed to stderr"
assert_equals "2" "$(grep -c 'hooks.slack.com' "$CURL_LOG")" "warning cross-reported via working Slack channel"
teardown_stub

# Both unconfigured -> exit 0, stderr warns about both, no curl calls
setup_stub
err="$STUB_DIR/err"
echo '{"cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-CHANGEME" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" \
  bash "$HOOKS/notify-session-start.sh" 2>"$err"; rc=$?
assert_equals "0" "$rc" "session-start exits 0 when both unconfigured"
assert_contains "Slack not configured" "$(cat "$err")" "warns Slack not configured"
assert_contains "ntfy not configured" "$(cat "$err")" "warns ntfy not configured"
assert_equals "" "$(cat "$CURL_LOG")" "no curl calls when both unconfigured"
teardown_stub

echo "All session-start tests passed."
