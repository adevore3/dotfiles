#!/bin/bash
# Stop hook: notifies that Claude finished — via ntfy.sh (NTFY_TOPIC) AND Slack
# (SLACK_WEBHOOK_URL). Either channel is skipped if its secret is unset. See claude/README.md.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/notify-lib.sh"   # provides slack_send + secret sourcing

TOPIC="${NTFY_TOPIC:-claude-CHANGEME}"

INPUT="$(cat)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null | cut -c1-6)"
DIR="$(basename "${CWD:-$PWD}")"

# Label priority: $CLAUDE_LABEL > meaningful tmux window name > cwd basename
LABEL=""
if [ -n "${CLAUDE_LABEL:-}" ]; then
  LABEL="$CLAUDE_LABEL"
elif [ -n "${TMUX_PANE:-}" ]; then
  WIN=$(tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null)
  case "$WIN" in
    ''|bash|zsh|sh|fish|tmux) ;;
    *[!0-9]*) LABEL="$WIN" ;;   # has at least one non-digit -> a real name
  esac
fi
[ -z "$LABEL" ] && LABEL="$DIR"
LABEL=$(printf '%s' "$LABEL" | tr -d '\r\n' | cut -c1-60)

BODY="Done in ${DIR}"
[ -n "$SID" ] && BODY="${BODY} · ${SID}"

# ntfy (skipped if topic not configured)
if [ "$TOPIC" != "claude-CHANGEME" ]; then
  curl -fsS -H "Title: ${LABEL}" -H "Tags: robot" -d "$BODY" "https://ntfy.sh/${TOPIC}" > /dev/null 2>&1 &
fi

# Slack (skipped by slack_send if webhook not configured)
slack_send ":white_check_mark: ${BODY}" "$DIR"

exit 0
