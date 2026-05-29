#!/bin/bash
# Stop hook: dynamic "done" notification. Reads Claude's last message from the transcript,
# includes a snippet, and flags whether it needs your input (heuristic + the <!-- needs-input -->
# marker). Prefers Slack; falls back to ntfy on any Slack failure. See claude/README.md.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/notify-lib.sh"

read_hook_context   # sets DIR, LABEL, SID, TRANSCRIPT

text=$(last_assistant_text)
urgency=$(classify_urgency "$text")
snip=$(snippet "$text")

if [ "$urgency" = "input" ]; then
  slack_text=":question: *Needs your input*"
  [ -n "$snip" ] && slack_text="${slack_text} — ${snip}"
  ntfy_title="❓ ${LABEL}"
  ntfy_body="${snip:-Needs your input}"
  prio="high"
  tags="question"
else
  base="Done in ${DIR}"
  [ -n "$SID" ] && base="${base} · ${SID}"
  slack_text=":white_check_mark: *${base}*"
  [ -n "$snip" ] && slack_text="${slack_text} — ${snip}"
  ntfy_title="✅ ${LABEL}"
  ntfy_body="$base"
  [ -n "$snip" ] && ntfy_body="${ntfy_body} — ${snip}"
  prio="low"
  tags="white_check_mark,robot"
fi

slack_send "$slack_text" "$DIR"
case $? in
  0) ;;                                                                            # delivered to Slack
  1) ntfy_send "$ntfy_title" "$ntfy_body" "$prio" "$tags" ;;                        # Slack not configured
  2) ntfy_send "$ntfy_title" "$ntfy_body (⚠️ Slack delivery failed)" "$prio" "$tags" ;;  # Slack failed
esac

exit 0
