#!/bin/bash
# Stop hook: notifies that Claude finished. Prefers Slack; falls back to ntfy on any Slack
# failure, noting when Slack was configured but failed. Exactly one notification. See claude/README.md.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/notify-lib.sh"

read_hook_context   # sets DIR, LABEL, SID

BODY="Done in ${DIR}"
[ -n "$SID" ] && BODY="${BODY} · ${SID}"

slack_send ":white_check_mark: ${BODY}" "$DIR"
case $? in
  0) ;;                                                          # delivered to Slack
  1) ntfy_send "$LABEL" "$BODY" ;;                               # Slack not configured -> ntfy plain
  2) ntfy_send "$LABEL" "$BODY (⚠️ Slack delivery failed)" ;;    # Slack failed -> ntfy + note
esac

exit 0
