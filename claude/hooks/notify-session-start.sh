#!/bin/bash
# SessionStart hook: notifies BOTH channels that a session started and warns (in-session via
# stderr + cross-reported on any working channel) if either is unconfigured or fails. Never
# blocks the session (always exits 0). See claude/README.md.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/notify-lib.sh"

read_hook_context   # sets DIR, LABEL, SID, TRANSCRIPT

MSG="Session started · ${LABEL}"
[ -n "$SID" ] && MSG="${MSG} · ${SID}"

slack_send ":large_green_circle: ${MSG}" "$DIR"; slack_rc=$?
ntfy_send "$LABEL" "$MSG"; ntfy_rc=$?

warnings=()
case $slack_rc in 1) warnings+=("Slack not configured");; 2) warnings+=("Slack delivery failed");; esac
case $ntfy_rc  in 1) warnings+=("ntfy not configured");;  2) warnings+=("ntfy delivery failed");;  esac

if [ "${#warnings[@]}" -gt 0 ]; then
  joined=$(printf '%s; ' "${warnings[@]}"); joined="${joined%; }"
  warn_text="session-start check: ${joined}"
  echo "⚠️ ${warn_text}" >&2                                        # (a) in-session (transcript)
  [ "$slack_rc" -eq 0 ] && slack_send ":warning: ${warn_text}" "$DIR"   # (b) cross-report via Slack
  [ "$ntfy_rc"  -eq 0 ] && ntfy_send "$LABEL" "⚠️ ${warn_text}"        #     cross-report via ntfy
fi

exit 0
