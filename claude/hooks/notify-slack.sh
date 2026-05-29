#!/bin/bash
# Notification hook: pings Slack when Claude Code needs attention, with a best-effort
# local desktop popup as a fallback. Portable across Linux (incl. headless) and macOS.
# Secret: SLACK_WEBHOOK_URL (see claude/README.md).

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/notify-lib.sh"

INPUT=$(cat)
MSG=$(echo "$INPUT" | jq -r '.message // "Claude Code needs your attention"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
PROJECT=$(basename "$CWD")

# Best-effort local desktop popup; no-op (returns non-zero) on headless boxes.
notify_desktop() {
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'on run argv
display notification (item 1 of argv) with title "Claude Code" subtitle (item 2 of argv) sound name "Glass"
end run' "$MSG" "$PROJECT" 2>/dev/null
  elif command -v notify-send >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    notify-send "Claude Code — $PROJECT" "$MSG" 2>/dev/null
  else
    return 1
  fi
}

# Prefer Slack (works headless); fall back to a desktop popup if Slack isn't configured.
slack_send ":robot_face: ${MSG}" "$PROJECT" || notify_desktop || \
  echo "[notify-slack] no notification channel available (set SLACK_WEBHOOK_URL)" >&2

exit 0
