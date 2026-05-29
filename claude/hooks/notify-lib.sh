#!/bin/bash
# Shared helpers for the Claude Code notification hooks (notify-slack.sh, notify-done.sh,
# notify-session-start.sh). Centralizes secret sourcing, the Slack/ntfy posts, and parsing
# the hook's stdin JSON. See claude/README.md.

# Pull secrets from a non-login-shell-safe fallback file if present (env/~/.localrc wins).
[ -f "$HOME/.claude/secrets.env" ] && source "$HOME/.claude/secrets.env"

# read_hook_context: reads the hook's stdin JSON once and sets globals DIR, LABEL, SID, TRANSCRIPT.
#   DIR        = basename of .cwd (or $PWD if absent)
#   SID        = first 6 chars of .session_id (may be empty)
#   TRANSCRIPT = .transcript_path (path to the session JSONL; may be empty)
#   LABEL      = $CLAUDE_LABEL > meaningful tmux window name > DIR, sanitized for HTTP headers
read_hook_context() {
  local input cwd win
  input="$(cat)"
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
  # shellcheck disable=SC2034  # SID is a global consumed by the sourcing script
  SID="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null | cut -c1-6)"
  # shellcheck disable=SC2034  # TRANSCRIPT is a global consumed by the sourcing script
  TRANSCRIPT="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
  DIR="$(basename "${cwd:-$PWD}")"
  LABEL=""
  if [ -n "${CLAUDE_LABEL:-}" ]; then
    LABEL="$CLAUDE_LABEL"
  elif [ -n "${TMUX_PANE:-}" ]; then
    win=$(tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null)
    case "$win" in
      ''|bash|zsh|sh|fish|tmux) ;;
      *[!0-9]*) LABEL="$win" ;;   # has at least one non-digit -> a real name
    esac
  fi
  [ -z "$LABEL" ] && LABEL="$DIR"
  LABEL=$(printf '%s' "$LABEL" | tr -d '\r\n' | cut -c1-60)
}

# last_assistant_text: echoes the text of the last assistant text block in $TRANSCRIPT (empty if none).
last_assistant_text() {
  { [ -n "${TRANSCRIPT:-}" ] && [ -f "$TRANSCRIPT" ]; } || return 0
  jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // empty' \
    "$TRANSCRIPT" 2>/dev/null || true
}

# classify_urgency <text> -> echoes "input" (needs the user) or "fyi" (informational).
# Order: explicit marker > trailing question mark > decision-cue phrases > fyi.
classify_urgency() {
  local text="${1:-}" last
  case "$text" in *'<!-- needs-input -->'*) echo input; return;; esac
  last=$(printf '%s' "$text" | grep -v '^[[:space:]]*$' | tail -n1 || true)
  case "$last" in *\?) echo input; return;; esac
  if printf '%s' "$text" | grep -qiE 'which|should i|let me know|your call|option|do you want|approve|confirm|prefer'; then
    echo input; return
  fi
  echo fyi
}

# snippet <text> -> one-line, marker-stripped, whitespace-collapsed, truncated to 200 chars (+ …).
snippet() {
  local text="${1:-}" s
  s=$(printf '%s' "$text" | sed 's/<!-- needs-input -->//g' | tr '\n\r\t' '   ' | tr -s ' ')
  s="${s# }"; s="${s% }"
  [ "${#s}" -gt 200 ] && s="${s:0:200}…"
  printf '%s' "$s"
}

# slack_send <markdown-text> <project-label>
#   0 = delivered | 1 = not configured (placeholder) | 2 = configured but POST failed
slack_send() {
  local text="${1:-}" project="${2:-}" url payload
  url="${SLACK_WEBHOOK_URL:-YOUR_SLACK_WEBHOOK_URL}"
  [[ "$url" == https://hooks.slack.com/services/* ]] || return 1
  payload=$(jq -n --arg text "$text" --arg project "$project" '{
    blocks: [
      { type: "section", text: { type: "mrkdwn", text: $text } },
      { type: "context", elements: [ { type: "mrkdwn", text: ("*Project:* " + $project) } ] }
    ]
  }')
  curl -fsS --max-time 5 -X POST -H 'Content-type: application/json' --data "$payload" "$url" >/dev/null 2>&1 && return 0 || return 2
}

# ntfy_send <title> <body> [priority] [tags]
#   0 = delivered | 1 = not configured (placeholder) | 2 = configured but POST failed
ntfy_send() {
  local title="${1:-}" body="${2:-}" priority="${3:-default}" tags="${4:-robot}" topic
  topic="${NTFY_TOPIC:-claude-CHANGEME}"
  [ "$topic" != "claude-CHANGEME" ] || return 1
  curl -fsS --max-time 5 -H "Title: ${title}" -H "Priority: ${priority}" -H "Tags: ${tags}" \
    -d "$body" "https://ntfy.sh/${topic}" >/dev/null 2>&1 && return 0 || return 2
}
