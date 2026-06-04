#!/bin/bash
# Stop hook: dynamic "done" notification. Reads Claude's last message from the transcript,
# includes a snippet, and flags whether it needs your input (heuristic + the <!-- needs-input -->
# marker). Slack-only by default; set NTFY_FALLBACK=1 to fall back to ntfy on any Slack failure.
# See claude/README.md.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/notify-lib.sh"

read_hook_context   # sets DIR, LABEL, SID, TRANSCRIPT

text=$(last_assistant_text)
urgency=$(classify_urgency "$text")
snip=$(snippet "$text")
# Slack carries the full message (chunked by slack_send): strip the input marker, then convert
# Claude's GitHub-flavored markdown to Slack mrkdwn so it renders natively. ntfy keeps the snippet.
body=$(printf '%s' "$text" | sed 's/<!-- needs-input -->//g')
body=$(md_to_mrkdwn "$body")

# Session identity leads every message so you can tell which session pinged.
ident="${DIR}"
[ -n "$SID" ] && ident="${ident} · ${SID}"

if [ "$urgency" = "input" ]; then
  emoji=":question:"; ntfy_title="❓ ${LABEL}"; prio="high"; tags="question"
else
  emoji=":white_check_mark:"; ntfy_title="✅ ${LABEL}"; prio="low"; tags="white_check_mark,robot"
fi

slack_text="${emoji} *${ident}*"
[ -n "$body" ] && slack_text="${slack_text}"$'\n'"${body}"
ntfy_body="$ident"
[ -n "$snip" ] && ntfy_body="${ntfy_body} — ${snip}"

slack_send "$slack_text" "$DIR"
rc=$?
# ntfy is an opt-in fallback only (NTFY_FALLBACK=1); otherwise Slack is the sole channel and a
# failure just logs to stderr.
if [ "${NTFY_FALLBACK:-0}" = "1" ]; then
  case $rc in
    0) ;;                                                                            # delivered to Slack
    1) ntfy_send "$ntfy_title" "$ntfy_body" "$prio" "$tags" ;;                        # Slack not configured
    2) ntfy_send "$ntfy_title" "$ntfy_body (⚠️ Slack delivery failed)" "$prio" "$tags" ;;  # Slack failed
  esac
elif [ "$rc" != "0" ]; then
  echo "[notify-done] Slack not delivered (rc=$rc); ntfy fallback disabled (set NTFY_FALLBACK=1)" >&2
fi

exit 0
