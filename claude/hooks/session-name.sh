#!/usr/bin/env bash
# Derives a stable, per-session display name: "<parent>/<leaf> @ <start-time>" where the directory and start time both
# come from the session's transcript -- i.e. the path Claude started in and when it started. Transcript-derived (not
# stored) so the name survives reboots and `claude --resume`, pins to the startup dir even after `cd` within the
# session, and is unique per pane/session rather than per tmux window. Sourced by the statusline and the Slack hooks.
#
# Usage: session_name "<transcript_path>" "<session_id>" "<fallback_cwd>"
# Echoes the name; never fails. Falls back to the live cwd (path only) when the transcript isn't readable yet.
session_name() {
  local transcript="$1" sid="$2" fallback_cwd="${3:-}"
  local line start_cwd start_ts name when matches

  # The statusline payload may omit transcript_path; the glob finds the transcript by session id regardless of which
  # project dir it lives under.
  if { [ -z "$transcript" ] || [ ! -f "$transcript" ]; } && [ -n "$sid" ]; then
    matches=( "$HOME"/.claude/projects/*/"$sid".jsonl )
    [ -f "${matches[0]}" ] && transcript="${matches[0]}"
  fi

  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    # First entry carrying both fields = the original startup dir and session start time. Tab-delimited so a cwd with
    # spaces survives the split below.
    line=$(jq -rc 'select(.cwd != null and .timestamp != null) | "\(.cwd)\t\(.timestamp)"' "$transcript" 2>/dev/null | head -n1)
    start_cwd=${line%$'\t'*}
    start_ts=${line##*$'\t'}
  fi

  [ -z "$start_cwd" ] && start_cwd="${fallback_cwd:-$PWD}"

  name="$(basename "$(dirname "$start_cwd")")/$(basename "$start_cwd")"   # last two path components

  if [ -n "${start_ts:-}" ]; then
    # ISO (UTC) -> Pacific. Forced to a fixed zone (not the machine's, which is UTC on cloud VMs); America/Los_Angeles
    # tracks PST/PDT across DST. Override with CLAUDE_SESSION_TZ if you want a different zone.
    when=$(TZ="${CLAUDE_SESSION_TZ:-America/Los_Angeles}" date -d "$start_ts" +"%Y-%m-%d_%H:%M_%Z" 2>/dev/null)
    [ -n "$when" ] && name="${name} @ ${when}"
  fi

  printf '%s' "$name"
}
