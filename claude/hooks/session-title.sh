#!/usr/bin/env bash
# UserPromptSubmit hook that titles the session after the Jira ticket being worked on.
#
# Prompt text is the primary signal: you normally name the ticket before a branch exists, and the session's cwd is
# often not the repo the work happens in (a session started in the main checkout while the edits land in worktrees or
# sibling clones never sees a ticket branch at all). The cwd's git branch, then its directory name, are the fallback.
#
# What that signal means depends on *when* it arrives. A key in the session's opening prompt is you starting work, so
# it titles outright. Later, in a session still untitled, the same key is usually a reference -- if the ticket were the
# subject you would have led with it -- so it has to be corroborated first: the branch or directory names that ticket
# too, or you name it again in a second prompt. Without that rule any quoted key renames the session you are in, which
# is how this hook came to be titled after a ticket quoted out of a claude_resume listing.
#
# When the signal is ambiguous the hook does not guess, it asks. Two keys in one prompt with no title yet, or a new key
# turning up after a title is set, both emit additionalContext asking Claude to put the question to you. That is the
# only way to tell "I'm switching to DIRP-4698" apart from "as I mentioned in DIRP-4683", which are identical inputs.
# Capped at MAX_ASKS per session so it can't nag.
#
# It never overwrites a title you set by hand. The payload's session_title carries only the custom title
# (jT() -> currentSessionTitle), never the AI-generated one (Pqe() -> currentSessionAiTitle), so a non-empty value the
# hook didn't write means you renamed it, and the hook backs off permanently for that session. The state file keeps
# recording the title either way, because it is what claude_resume displays (see claude_resume.py's load_custom_titles).
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
# How many separate prompts must name a ticket before it can title a session that is already underway. Raise it if
# discussing a ticket for a couple of turns keeps claiming sessions that are really about something else.
MIN_SIGHTINGS="${CLAUDE_SESSION_TITLE_MIN_SIGHTINGS:-2}"
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

# seen crosses the boundary as "KEY:COUNT KEY:COUNT", the same space-joined shape as declined and pending: bash 3.2
# has no associative arrays, and the counts are what tell a ticket you keep working on from one you mentioned once.
override=false set_key="" set_title="" asks=0 declined="" pending="" prompts=0 seen=""
if [ -s "$state" ]; then
  {
    IFS= read -r -d '' override
    IFS= read -r -d '' set_key
    IFS= read -r -d '' set_title
    IFS= read -r -d '' asks
    IFS= read -r -d '' declined
    IFS= read -r -d '' pending
    IFS= read -r -d '' prompts
    IFS= read -r -d '' seen
  } < <(jq -j '
    (.override // false | tostring), "\u0000",
    (.set_key // ""), "\u0000",
    (.set_title // ""), "\u0000",
    (.asks // 0 | tostring), "\u0000",
    ((.declined // []) | join(" ")), "\u0000",
    ((.pending // []) | join(" ")), "\u0000",
    (.prompts // 0 | tostring), "\u0000",
    ((.seen // {}) | to_entries | map("\(.key):\(.value)") | join(" ")), "\u0000"' "$state")
fi

save_state() {
  jq -n --argjson override "$override" --arg set_key "$set_key" --arg set_title "$set_title" \
        --argjson asks "$asks" --arg declined "$declined" --arg pending "$pending" \
        --argjson prompts "$prompts" --arg seen "$seen" \
    '{override: $override, set_key: $set_key, set_title: $set_title, asks: $asks,
      declined: ($declined | split(" ") | map(select(. != ""))),
      pending:  ($pending  | split(" ") | map(select(. != ""))),
      prompts: $prompts,
      seen: ($seen | split(" ") | map(select(. != "")) |
             map(split(":") | {key: .[0], value: (.[1] | tonumber)}) | from_entries)}' > "$state"
}

# Backing off is permanent: once you have named the session yourself, the hook has nothing useful to add. The name you
# chose still goes into set_title, because that field is the only durable record of a session's custom title -- Claude
# keeps the custom title out of the transcript, so claude_resume reads it from here, and leaving it blank would send
# the list back to the AI title for exactly the sessions you named deliberately. Nothing compares against set_title
# once override is set, so recording your name in it costs nothing. Re-check it on later prompts too: a second rename
# would otherwise leave the file holding the first one forever.
if [ "$override" = "true" ]; then
  if [ -n "${cur:-}" ] && [ "$cur" != "$set_title" ]; then
    set_title="$cur"
    save_state
  fi
  exit 0
fi
if [ -n "${cur:-}" ] && [ "$cur" != "$set_title" ]; then
  override=true set_title="$cur" pending=""
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

seen_count() {  # seen_count <key> -- how many separate prompts have named it
  local entry
  for entry in $seen; do
    [ "${entry%%:*}" = "$1" ] && { printf '%s' "${entry##*:}"; return; }
  done
  printf '0'
}

# One sighting per prompt per key, not per occurrence: naming a ticket three times in one message is one prompt.
bump_seen() {
  local entry key out="" bumped=""
  for entry in $seen; do
    key="${entry%%:*}"
    if contains "$key" "$keys"; then
      out="$out $key:$(( ${entry##*:} + 1 ))"
      bumped="$bumped $key"
    else
      out="$out $entry"
    fi
  done
  for key in $keys; do
    contains "$key" "$bumped" || out="$out $key:1"
  done
  seen="${out# }"
}

# The ticket the session is physically sitting on: corroboration for a key in the prompt, and on its own the only
# signal an untitled session has when you never name a ticket at all.
cwd_key() {
  local key=""
  if [ -n "${cwd:-}" ] && [ -d "$cwd" ] && command -v git >/dev/null; then
    # symbolic-ref, not rev-parse --abbrev-ref: it still reports the branch on a repo with no commits yet, and stays
    # quiet on a detached HEAD instead of returning the literal "HEAD".
    key=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null | grep -oE "$KEY_RE" | head -1)
  fi
  [ -z "$key" ] && [ -n "${cwd:-}" ] && key=$(basename -- "$cwd" | grep -oE "$KEY_RE" | head -1)
  printf '%s' "$key"
}

key_list() { printf '%s' "$1" | tr ' ' ',' | sed 's/,/, /g'; }

# Asking is only ever about which ticket an *untitled* session is on; the titled case has its own wording below.
ask_untitled() {  # ask_untitled <keys>
  [ "$asks" -ge "$MAX_ASKS" ] && { save_state; return; }
  asks=$((asks + 1)) pending="$1"
  save_state
  emit_ask "The session has no title yet and more than one Jira ticket ($(key_list "$1")) reads like its subject. Ask the user which one this session is about, in plain text rather than a picker, and ask them to reply with the full ticket key. Their reply sets the session title automatically, so do not try to set it yourself. Keep the question to one line and then carry on with their actual request."
}

keys=$(printf '%s' "$prompt" | grep -oE "$KEY_RE" | awk '!seen[$0]++' | tr '\n' ' ')
keys="${keys% }"

# Count every prompt, keys or not. Which prompt this is and how many prompts have named a given ticket are the two
# facts that separate the work from a passing mention, and neither can be recovered after the fact -- rescanning the
# transcript is far too slow for a hook that runs ahead of every prompt, and Claude keeps no such tally of its own.
prompts=$((prompts + 1))
bump_seen

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

count=$(printf '%s' "$candidates" | wc -w | tr -d ' ')

# A title already exists, so any different key is the switch-or-citation question the hook cannot answer on its own.
# The title itself never moves on a mention alone -- only your answer moves it.
if [ -n "$set_key" ]; then
  [ -z "$candidates" ] && exit 0
  newkeys=""
  for k in $candidates; do
    [ "$k" != "$set_key" ] && newkeys="$newkeys $k"
  done
  newkeys="${newkeys# }"

  [ -z "$newkeys" ] && exit 0
  [ "$asks" -ge "$MAX_ASKS" ] && exit 0

  asks=$((asks + 1)) pending="$newkeys"
  save_state
  emit_ask "This session is titled for $set_key, and this prompt names $(key_list "$newkeys"). Ask the user whether the session has moved to that ticket or whether it is just a reference, in plain text rather than a picker, and ask them to reply with the full ticket key if it is a switch. Their reply retitles the session automatically, so do not try to set it yourself. Keep the question to one line and then carry on with their actual request."
  exit 0
fi

# The opening prompt is you starting work, so one unambiguous key there titles the session outright -- and outranks
# the branch you happen to be sitting in, since you often name the ticket before its worktree exists.
if [ "$prompts" -le 1 ] && [ -n "$candidates" ]; then
  if [ "$count" -eq 1 ]; then
    set_title_for "$candidates"
    exit 0
  fi
  ask_untitled "$candidates"
  exit 0
fi

# Past the opening prompt, a key has to be corroborated before it can name the session. An untitled session that has
# already run a few prompts is a session whose subject is *not* the ticket you just typed -- if it were, you would
# have led with it -- so a lone mention is recorded and otherwise ignored. This hook was itself misnamed by a prompt
# that quoted a ticket key out of a claude_resume listing. Corroboration is either signal: the branch or directory
# you are working in names the ticket, or you have now named it in two separate prompts.
qualified=""
for k in $candidates; do
  [ "$(seen_count "$k")" -ge "$MIN_SIGHTINGS" ] && qualified="$qualified $k"
done
dirkey=$(cwd_key)
if [ -n "$dirkey" ] && ! contains "$dirkey" "$declined" && ! contains "$dirkey" "$qualified"; then
  qualified="$qualified $dirkey"
fi
qualified="${qualified# }"

case "$(printf '%s' "$qualified" | wc -w | tr -d ' ')" in
  0) save_state ;;
  1) set_title_for "$qualified" ;;
  *) ask_untitled "$qualified" ;;
esac
exit 0
