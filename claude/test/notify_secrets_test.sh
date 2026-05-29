#!/bin/bash
# Tests that the notify hooks read their secret from the environment, that the Stop hook
# (notify-done) posts to both ntfy and Slack, and that each channel no-ops on its
# placeholder. A stub `curl` on PATH captures requests instead of hitting the network.
# HOME is pointed at a temp dir per run so a real ~/.claude/secrets.env cannot leak in.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
HOOKS="$DIR/../hooks"

setup_stub() {
  STUB_DIR="$(mktemp -d)"
  export CURL_LOG="$STUB_DIR/curl.log"
  : > "$CURL_LOG"
  cat > "$STUB_DIR/curl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$CURL_LOG"
exit 0
STUB
  chmod +x "$STUB_DIR/curl"
  export PATH="$STUB_DIR:$PATH"
}
teardown_stub() { export PATH="${PATH#"$STUB_DIR":}"; rm -rf "$STUB_DIR"; }
wait_for_log() { for _ in $(seq 1 60); do [ -s "$CURL_LOG" ] && return 0; sleep 0.05; done; return 1; }

# notify-slack: posts to the env webhook
setup_stub
echo '{"message":"hi","cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T/B/zzz" bash "$HOOKS/notify-slack.sh"
assert_contains "https://hooks.slack.com/services/T/B/zzz" "$(cat "$CURL_LOG")" "notify-slack posts to env webhook"
teardown_stub

# notify-slack: no-op with placeholder
setup_stub
echo '{"message":"hi","cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-slack.sh"
assert_equals "" "$(cat "$CURL_LOG")" "notify-slack skips curl without a real webhook"
teardown_stub

# notify-done: posts to the env ntfy topic
setup_stub
echo '{"cwd":"/tmp/proj","session_id":"abc123"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-test-topic" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
wait_for_log
assert_contains "ntfy.sh/claude-test-topic" "$(cat "$CURL_LOG")" "notify-done posts to env ntfy topic"
teardown_stub

# notify-done: ALSO posts the done message to Slack when the webhook is set
setup_stub
echo '{"cwd":"/tmp/proj","session_id":"abc123"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-CHANGEME" SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T/B/zzz" bash "$HOOKS/notify-done.sh"
wait_for_log
assert_contains "https://hooks.slack.com/services/T/B/zzz" "$(cat "$CURL_LOG")" "notify-done also posts done to Slack"
teardown_stub

# notify-done: skips both channels when neither secret is configured
setup_stub
echo '{"cwd":"/tmp/proj"}' | \
  HOME="$STUB_DIR" NTFY_TOPIC="claude-CHANGEME" SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL" bash "$HOOKS/notify-done.sh"
assert_equals "" "$(cat "$CURL_LOG")" "notify-done skips both channels when unconfigured"
teardown_stub

echo "All notify secret tests passed."
