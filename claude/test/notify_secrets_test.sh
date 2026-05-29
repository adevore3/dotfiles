#!/bin/bash
# Tests notify-slack (Notification) and notify-done (Stop: Slack-preferred, ntfy fallback).
# Uses the stub curl from notify_test_helpers.sh and a temp HOME so a real ~/.claude/secrets.env
# can't leak in.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
source "$DIR/notify_test_helpers.sh"
HOOKS="$DIR/../hooks"
SLACK_OK="https://hooks.slack.com/services/T/B/zzz"

# --- notify-slack (Notification) ---
setup_stub
echo '{"message":"hi","cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" SLACK_WEBHOOK_URL="$SLACK_OK" bash "$HOOKS/notify-slack.sh"
assert_contains "$SLACK_OK" "$(cat "$CURL_LOG")" "notify-slack posts to env webhook"
teardown_stub

setup_stub
echo '{"message":"hi","cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-slack.sh"
assert_equals "" "$(cat "$CURL_LOG")" "notify-slack skips curl without a real webhook"
teardown_stub

# --- notify-done (Stop): Slack preferred, ntfy fallback ---

# Slack delivers -> ntfy NOT called
setup_stub
echo '{"cwd":"/tmp/proj","session_id":"abc123"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="$SLACK_OK" bash "$HOOKS/notify-done.sh"
assert_contains "$SLACK_OK" "$(cat "$CURL_LOG")" "notify-done posts to Slack when configured"
assert_equals "0" "$(grep -c 'ntfy.sh' "$CURL_LOG")" "notify-done does NOT call ntfy when Slack delivers"
teardown_stub

# Slack not configured -> ntfy plain (no failure note)
setup_stub
echo '{"cwd":"/tmp/proj","session_id":"abc123"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
assert_contains "ntfy.sh/claude-test-topic" "$(cat "$CURL_LOG")" "notify-done falls back to ntfy when Slack unconfigured"
assert_equals "0" "$(grep -c 'Slack delivery failed' "$CURL_LOG")" "no failure note when Slack simply unconfigured"
teardown_stub

# Slack configured but FAILS -> ntfy fallback WITH failure note
setup_stub
echo '{"cwd":"/tmp/proj","session_id":"abc123"}' | \
  HOME="$STUB_DIR" FAIL_SLACK=1 NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="$SLACK_OK" bash "$HOOKS/notify-done.sh"
assert_contains "ntfy.sh/claude-test-topic" "$(cat "$CURL_LOG")" "notify-done falls back to ntfy when Slack fails"
assert_contains "Slack delivery failed" "$(cat "$CURL_LOG")" "ntfy message notes the Slack failure"
teardown_stub

# Neither configured -> nothing
setup_stub
echo '{"cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-CHANGEME" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
assert_equals "" "$(cat "$CURL_LOG")" "notify-done does nothing when neither channel configured"
teardown_stub

echo "All notify-done/slack tests passed."
