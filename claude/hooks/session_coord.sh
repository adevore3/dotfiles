#!/usr/bin/env bash
# Cross-session collision awareness for parallel Claude Code worktrees. Registered as PreToolUse + PostToolUse hooks.
#
# Two Claude sessions running in different git worktrees of one repo share the machine's local state (e.g. a shared
# local artifact repo, docker image tags, ports). This engine watches Bash commands against a config-supplied list of
# "resource" regexes; when one worktree is mid-<resource-command>, a second worktree starting the SAME class of command
# gets a non-blocking warning injected into its agent context so it can decide to wait. Warn-only -- never blocks.
#
# Generic mechanism, no project-specific strings: the watched patterns live in config dropped by another repo (see
# below). No config -> silent no-op, so this is safe on any machine / in any repo.
#
# Usage (from settings.json hooks):
#   session_coord.sh pre    < hook-json     # PreToolUse: announce + warn on contention
#   session_coord.sh post   < hook-json     # PostToolUse: clear this worktree's claim
#
# Config: each non-blank, non-`#` line in $CLAUDE_SESSION_COORD_CONF/*.conf defines one watched resource, TAB-separated
# (tab because the regexes themselves contain `|`):
#   <resource-class>\t<extended-regex>[\t<hint>]
# `hint` (optional) is appended to the warning to explain the specific consequence of colliding.
#
# State: one file per worktree+resource under $CLAUDE_SESSION_COORD_DIR:  claim.<resource>.<wtkey>
# Claims are keyed by git-worktree-toplevel (fallback: cwd), so one worktree == one logical workspace. Stale claims
# (older than TTL, i.e. a session that died before PostToolUse) are pruned on the next pre.

set -uo pipefail

CONF_DIR="${CLAUDE_SESSION_COORD_CONF:-$HOME/.claude/session-coord.d}"
REGISTRY="${CLAUDE_SESSION_COORD_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-session-coord}"
TTL="${CLAUDE_SESSION_COORD_TTL:-3600}"

now() { date +%s; }

# Sanitize an arbitrary path into a safe, collision-resistant filename component.
sanitize() { printf '%s' "$1" | tr '/ ' '__' | tr -cd '[:alnum:]._-'; }

# Echo "<resource>\t<hint>" for the first config regex matching $1, else nothing.
match_resource() {
  local cmd="$1" class regex hint
  [ -d "$CONF_DIR" ] || return 0
  while IFS=$'\t' read -r class regex hint; do
    case "$class" in ''|\#*) continue ;; esac
    [ -n "$regex" ] || continue
    if printf '%s' "$cmd" | grep -Eq "$regex"; then
      printf '%s\t%s' "$class" "$hint"
      return 0
    fi
  done < <(cat "$CONF_DIR"/*.conf 2>/dev/null)
}

# git worktree toplevel for a cwd, falling back to the cwd itself.
worktree_root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$1"; }

# One field's value from a claim file (everything after the first `=`).
read_field() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }

# Resolve the session description, best-to-worst: note override -> transcript -> branch. Trimmed to one line, 80 chars.
resolve_description() {
  local cwd="$1" transcript="$2" wtkey="$3" note desc=""
  note="$REGISTRY/note.$wtkey"
  if [ -f "$note" ]; then
    desc="$(cat "$note")"
  elif [ -n "$transcript" ] && [ -f "$transcript" ]; then
    # Newest session summary if the transcript has one, else the first user message's text.
    desc="$(jq -rs 'map(select(.type=="summary") | .summary) | last // empty' "$transcript" 2>/dev/null)"
    [ -z "$desc" ] && desc="$(jq -rs 'map(select(.type=="user") | .message.content) | map(if type=="string" then . else (map(select(.type=="text") | .text) | join(" ")) end) | map(select(. != "")) | first // empty' "$transcript" 2>/dev/null)"
  fi
  [ -z "$desc" ] && desc="$(git -C "$cwd" branch --show-current 2>/dev/null)"
  printf '%s' "$desc" | tr -d '\r\n' | cut -c1-80
}

# Remove claim files for $1 older than TTL (crash insurance on top of PostToolUse).
prune_stale() {
  local resource="$1" f start cutoff
  cutoff=$(( $(now) - TTL ))
  for f in "$REGISTRY"/claim."$resource".*; do
    [ -e "$f" ] || continue
    start="$(read_field "$f" start_epoch)"
    [ -n "$start" ] && [ "$start" -lt "$cutoff" ] 2>/dev/null && rm -f "$f"
  done
}

# Parse the shared hook stdin JSON once into globals; return 1 unless it's a Bash tool call.
parse_input() {
  local input; input="$(cat)"
  [ "$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" = "Bash" ] || return 1
  CMD="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  CWD="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"; CWD="${CWD:-$PWD}"
  SID="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
  TRANSCRIPT="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
}

emit_warning() {  # emit_warning <message>
  jq -cn --arg m "$1" \
    '{systemMessage:$m, hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", additionalContext:$m}}'
}

cmd_pre() {
  parse_input || return 0
  local match; match="$(match_resource "$CMD")"; [ -n "$match" ] || return 0
  local resource="${match%%$'\t'*}" hint="${match#*$'\t'}"
  mkdir -p "$REGISTRY"
  prune_stale "$resource"

  local root wtkey; root="$(worktree_root "$CWD")"; wtkey="$(sanitize "$root")"

  # Collect warnings from OTHER worktrees holding an active claim on this resource.
  local warnings="" f ob obn odesc ostart ago line
  for f in "$REGISTRY"/claim."$resource".*; do
    [ -e "$f" ] || continue
    [ "$(read_field "$f" wtkey)" = "$wtkey" ] && continue
    ob="$(read_field "$f" branch)"; obn="$(read_field "$f" basename)"
    odesc="$(read_field "$f" description)"; ostart="$(read_field "$f" start_epoch)"
    ago=$(( ( $(now) - ${ostart:-0} ) / 60 ))
    line="⚠️ Another Claude session is mid-\`$resource\` — worktree \`${obn:-?}\`, branch \`${ob:-?}\`"
    [ -n "$odesc" ] && line="$line: \"$odesc\""
    line="$line (started ${ago} min ago)."
    [ -n "$hint" ] && line="$line $hint"
    line="$line Consider waiting until it clears."
    warnings="${warnings:+$warnings$'\n'}$line"
  done

  # Write this worktree's claim (atomic: temp file in the same dir, then mv).
  local desc tmp; desc="$(resolve_description "$CWD" "$TRANSCRIPT" "$wtkey")"
  tmp="$(mktemp "$REGISTRY/.claim.XXXXXX")"
  {
    printf 'resource=%s\n' "$resource"
    printf 'wtkey=%s\n' "$wtkey"
    printf 'worktree=%s\n' "$root"
    printf 'branch=%s\n' "$(git -C "$CWD" branch --show-current 2>/dev/null)"
    printf 'basename=%s\n' "$(basename "$root")"
    printf 'session_id=%s\n' "$SID"
    printf 'description=%s\n' "$desc"
    printf 'start_epoch=%s\n' "$(now)"
  } >"$tmp"
  mv -f "$tmp" "$REGISTRY/claim.$resource.$wtkey"

  [ -n "$warnings" ] && emit_warning "$warnings"
  return 0
}

cmd_post() {
  parse_input || return 0
  local match; match="$(match_resource "$CMD")"; [ -n "$match" ] || return 0
  local resource="${match%%$'\t'*}" root wtkey
  root="$(worktree_root "$CWD")"; wtkey="$(sanitize "$root")"
  rm -f "$REGISTRY/claim.$resource.$wtkey"
  return 0
}

case "${1:-}" in
  pre) cmd_pre ;;
  post) cmd_post ;;
  *) : ;;   # unknown mode: no-op
esac
exit 0
