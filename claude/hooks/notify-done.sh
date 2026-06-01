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

# Session identity leads every message so you can tell which session pinged.
ident="${DIR}"
[ -n "$SID" ] && ident="${ident} · ${SID}"

if [ "$urgency" = "input" ]; then
  emoji=":question:"; ntfy_title="❓ ${LABEL}"; prio="high"; tags="question"
else
  emoji=":white_check_mark:"; ntfy_title="✅ ${LABEL}"; prio="low"; tags="white_check_mark,robot"
fi

slack_text="${emoji} *${ident}*"
[ -n "$snip" ] && slack_text="${slack_text} — ${snip}"
ntfy_body="$ident"
[ -n "$snip" ] && ntfy_body="${ntfy_body} — ${snip}"

slack_send "$slack_text" "$DIR"
case $? in
  0) ;;                                                                            # delivered to Slack
  1) ntfy_send "$ntfy_title" "$ntfy_body" "$prio" "$tags" ;;                        # Slack not configured
  2) ntfy_send "$ntfy_title" "$ntfy_body (⚠️ Slack delivery failed)" "$prio" "$tags" ;;  # Slack failed
esac

exit 0
