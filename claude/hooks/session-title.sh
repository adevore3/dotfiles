#!/usr/bin/env bash
# UserPromptSubmit hook that titles the session after the Jira ticket being worked on.
#
# Prompt text is the primary signal: you normally name the ticket before a branch exists, and the session's cwd is
# often not the repo the work happens in (a session started in the main checkout while the edits land in worktrees or
# sibling clones never sees a ticket branch at all). The cwd's git branch, then its directory name, are the fallback.
#
# When the signal is ambiguous the hook does not guess, it asks. Two keys in one prompt with no title yet, or a new key
# turning up after a title is set, both emit additionalContext asking Claude to put the question to you. That is the
# only way to tell "I'm switching to DIRP-4698" apart from "as I mentioned in DIRP-4683", which are identical inputs.
# Capped at MAX_ASKS per session so it can't nag.
#
# It never overwrites a title you set by hand. The payload's session_title carries only the custom title
# (jT() -> currentSessionTitle), never the AI-generated one (Pqe() -> currentSessionAiTitle), so a non-empty value the
# hook didn't write means you renamed it, and the hook backs off permanently for that session.
#
# Always exits 0 and stays silent on any failure. This runs synchronously ahead of every prompt, so a hook that errors
# or hangs would block the session; nothing here is worth that.

set -u
exec 2>/dev/null

# All overridable so the tests can point at temp dirs and an unreadable netrc, which keeps them off the network:
# jira_summary bails when the netrc isn't readable, so an unseeded cache just yields a bare-key title.
STATE_DIR="${CLAUDE_SESSION_TITLE_STATE:-$HOME/.claude/state/session-title}"
CACHE_DIR="${CLAUDE_SESSION_TITLE_CACHE:-$HOME/.claude/state/jira-titles}"
NETRC="${CLAUDE_SESSION_TITLE_NETRC:-$HOME/.config/atlassian/confluence.netrc}"
JIRA_HOST="${CLAUDE_SESSION_TITLE_HOST:-indeed.atlassian.net}"
MAX_ASKS="${CLAUDE_SESSION_TITLE_MAX_ASKS:-2}"
MAX_TITLE="${CLAUDE_SESSION_TITLE_MAX_LEN:-70}"
KEY_RE='[A-Z][A-Z0-9]{1,9}-[0-9]+'

command -v jq >/dev/null || exit 0
mkdir -p "$STATE_DIR" "$CACHE_DIR" || exit 0

input=$(cat)
[ -n "$input" ] || exit 0

# NUL-delimited so a prompt containing newlines, quotes or backslashes survives the read intact.
{
  IFS= read -r -d '' sid
  IFS= read -r -d '' cur
  IFS= read -r -d '' cwd
  IFS= read -r -d '' prompt
} < <(printf '%s' "$input" | jq -j '
  (.session_id // ""), "\u0000",
  (.session_title // ""), "\u0000",
  (.cwd // ""), "\u0000",
  (.prompt // ""), "\u0000"')

[ -n "${sid:-}" ] || exit 0
state="$STATE_DIR/$sid.json"

override=false set_key="" set_title="" asks=0 declined="" pending=""
if [ -s "$state" ]; then
  {
    IFS= read -r -d '' override
    IFS= read -r -d '' set_key
    IFS= read -r -d '' set_title
    IFS= read -r -d '' asks
    IFS= read -r -d '' declined
    IFS= read -r -d '' pending
  } < <(jq -j '
    (.override // false | tostring), "\u0000",
    (.set_key // ""), "\u0000",
    (.set_title // ""), "\u0000",
    (.asks // 0 | tostring), "\u0000",
    ((.declined // []) | join(" ")), "\u0000",
    ((.pending // []) | join(" ")), "\u0000"' "$state")
fi

save_state() {
  jq -n --argjson override "$override" --arg set_key "$set_key" --arg set_title "$set_title" \
        --argjson asks "$asks" --arg declined "$declined" --arg pending "$pending" \
    '{override: $override, set_key: $set_key, set_title: $set_title, asks: $asks,
      declined: ($declined | split(" ") | map(select(. != ""))),
      pending:  ($pending  | split(" ") | map(select(. != "")))}' > "$state"
}

# Backing off is permanent: once you have named the session yourself, the hook has nothing useful to add.
[ "$override" = "true" ] && exit 0
if [ -n "${cur:-}" ] && [ "$cur" != "$set_title" ]; then
  override=true pending=""
  save_state
  exit 0
fi

emit_title() {
  jq -n --arg t "$1" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
}

emit_ask() {
  jq -n --arg c "$1" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
}

# Summary lookup is cached per key, so the network is touched at most once per ticket ever. curl reads the token from
# the netrc itself, keeping it out of argv and out of this transcript.
jira_summary() {
  local key="$1" cache="$CACHE_DIR/$1" summary
  if [ -s "$cache" ]; then
    cat "$cache"
    return
  fi
  [ -r "$NETRC" ] || return
  summary=$(curl -sS --max-time 6 --netrc-file "$NETRC" -H 'Accept: application/json' \
    "https://$JIRA_HOST/rest/api/3/issue/$key?fields=summary" | jq -r '.fields.summary // empty')
  [ -n "$summary" ] || return
  printf '%s' "$summary" > "$cache"
  printf '%s' "$summary"
}

set_title_for() {
  local key="$1" summary title
  summary=$(jira_summary "$key")
  if [ -n "$summary" ]; then
    title="$key $summary"
  else
    title="$key"
  fi
  [ "${#title}" -gt "$MAX_TITLE" ] && title="${title:0:$((MAX_TITLE - 1))}…"
  set_key="$key" set_title="$title" pending=""
  save_state
  emit_title "$title"
}

contains() {
  case " $2 " in *" $1 "*) return 0 ;; esac
  return 1
}

keys=$(printf '%s' "$prompt" | grep -oE "$KEY_RE" | awk '!seen[$0]++' | tr '\n' ' ')
keys="${keys% }"

# A pending question takes priority: this prompt is most likely the answer to it.
if [ -n "$pending" ]; then
  chosen=""
  for k in $pending; do
    contains "$k" "$keys" && chosen="$k" && break
  done
  # "4698" is a natural way to answer "which ticket?", so match a bare number against the pending keys too.
  if [ -z "$chosen" ]; then
    for n in $(printf '%s' "$prompt" | grep -oE '\b[0-9]{2,6}\b'); do
      for k in $pending; do
        [ "${k##*-}" = "$n" ] && chosen="$k" && break 2
      done
    done
  fi
  if [ -n "$chosen" ]; then
    for k in $pending; do
      [ "$k" != "$chosen" ] && declined="$declined $k"
    done
    set_title_for "$chosen"
    exit 0
  fi
  # Unanswered means you moved on. Drop the question rather than asking again.
  pending=""
  save_state
fi

candidates=""
for k in $keys; do
  contains "$k" "$declined" || candidates="$candidates $k"
done
candidates="${candidates# }"

# No ticket named in the prompt, so fall back to the branch, then the directory, but only to seed an untitled session.
if [ -z "$candidates" ] && [ -z "$set_key" ]; then
  bkey=""
  if [ -n "${cwd:-}" ] && [ -d "$cwd" ] && command -v git >/dev/null; then
    # symbolic-ref, not rev-parse --abbrev-ref: it still reports the branch on a repo with no commits yet, and stays
    # quiet on a detached HEAD instead of returning the literal "HEAD".
    bkey=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null | grep -oE "$KEY_RE" | head -1)
  fi
  [ -z "$bkey" ] && [ -n "${cwd:-}" ] && bkey=$(basename -- "$cwd" | grep -oE "$KEY_RE" | head -1)
  if [ -n "$bkey" ] && ! contains "$bkey" "$declined"; then
    set_title_for "$bkey"
  fi
  exit 0
fi

[ -z "$candidates" ] && exit 0

count=$(printf '%s' "$candidates" | wc -w | tr -d ' ')

if [ -z "$set_key" ]; then
  # One unambiguous ticket and no title yet, just take it.
  if [ "$count" -eq 1 ]; then
    set_title_for "$candidates"
    exit 0
  fi
  [ "$asks" -ge "$MAX_ASKS" ] && exit 0
  asks=$((asks + 1)) pending="$candidates"
  save_state
  emit_ask "The session has no title yet and this prompt names more than one Jira ticket ($(printf '%s' "$candidates" | tr ' ' ',' | sed 's/,/, /g')). Ask the user which one this session is about, in plain text rather than a picker, and ask them to reply with the full ticket key. Their reply sets the session title automatically, so do not try to set it yourself. Keep the question to one line and then carry on with their actual request."
  exit 0
fi

# A title already exists, so any different key is the switch-or-citation question the hook cannot answer on its own.
newkeys=""
for k in $candidates; do
  [ "$k" != "$set_key" ] && newkeys="$newkeys $k"
done
newkeys="${newkeys# }"

[ -z "$newkeys" ] && exit 0
[ "$asks" -ge "$MAX_ASKS" ] && exit 0

asks=$((asks + 1)) pending="$newkeys"
save_state
emit_ask "This session is titled for $set_key, and this prompt names $(printf '%s' "$newkeys" | tr ' ' ',' | sed 's/,/, /g'). Ask the user whether the session has moved to that ticket or whether it is just a reference, in plain text rather than a picker, and ask them to reply with the full ticket key if it is a switch. Their reply retitles the session automatically, so do not try to set it yourself. Keep the question to one line and then carry on with their actual request."
exit 0
