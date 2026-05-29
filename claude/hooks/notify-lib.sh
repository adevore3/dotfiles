#!/bin/bash
# Shared helpers for the Claude Code notification hooks. Sourced by notify-slack.sh
# (Notification event) and notify-done.sh (Stop event). Centralizes secret sourcing and
# the Slack post so the channel logic lives in one place. See claude/README.md.

# Pull secrets from a non-login-shell-safe fallback file if present (env/~/.localrc wins).
[ -f "$HOME/.claude/secrets.env" ] && source "$HOME/.claude/secrets.env"

# slack_send <markdown-text> <project-label>
# Posts a Block Kit message to $SLACK_WEBHOOK_URL. Returns non-zero (no-op) if the webhook
# is unset/placeholder. Never errors out the calling hook.
slack_send() {
  local text="$1" project="$2" url payload
  url="${SLACK_WEBHOOK_URL:-YOUR_SLACK_WEBHOOK_URL}"
  [[ "$url" == https://hooks.slack.com/services/* ]] || return 1
  payload=$(jq -n --arg text "$text" --arg project "$project" '{
    blocks: [
      { type: "section", text: { type: "mrkdwn", text: $text } },
      { type: "context", elements: [ { type: "mrkdwn", text: ("*Project:* " + $project) } ] }
    ]
  }')
  curl -fsS -X POST -H 'Content-type: application/json' --data "$payload" "$url" >/dev/null 2>&1
}
