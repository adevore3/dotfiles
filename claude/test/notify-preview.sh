#!/bin/bash
# Manual helper (NOT a *_test.sh, so the automated runner skips it — it can touch the network) to
# preview or send the notify-done Slack formatting using the saved fixtures in ./fixtures/.
#
#   notify-preview.sh                 # offline: show converted mrkdwn for every fixture (NBSP shown as ·)
#   notify-preview.sh notify-rich.md  # offline preview of one fixture (name or path)
#   notify-preview.sh --send          # fire the live Stop hook to Slack for every fixture
#   notify-preview.sh --send notify-nested.md
#
# --send actually posts to Slack and needs SLACK_WEBHOOK_URL in the environment (your ~/.localrc).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
FIXTURES="$DIR/fixtures"
HOOKS="$ROOT/claude/hooks"

source "$HOOKS/notify-lib.sh"   # provides md_to_mrkdwn() + MD_TO_MRKDWN_PY for the offline preview

send=0
[ "${1:-}" = "--send" ] && { send=1; shift; }

files=("$@")
[ ${#files[@]} -eq 0 ] && files=("$FIXTURES"/*.md)

for f in "${files[@]}"; do
  [ -f "$f" ] || f="$FIXTURES/$f"
  if [ ! -f "$f" ]; then echo "skip: no such fixture: $f" >&2; continue; fi
  echo "===== $(basename "$f") ====="
  md="$(cat "$f")"
  if [ "$send" -eq 1 ]; then
    tf="$(mktemp)"
    jq -nc --arg t "$md" '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:$t}]}}' > "$tf"
    printf '%s' '{"cwd":"'"$ROOT"'","session_id":"manual","transcript_path":"'"$tf"'"}' | bash "$HOOKS/notify-done.sh"
    echo "[sent to Slack, exit $?]"
    rm -f "$tf"
  else
    body="$(printf '%s' "$md" | sed 's/<!-- needs-input -->//g')"
    # Show the converted body exactly as slack_send would chunk it; render NBSP as · so nested
    # bullet indentation is visible in a terminal.
    md_to_mrkdwn "$body" | sed 's/\xc2\xa0/·/g'
  fi
  echo
done
