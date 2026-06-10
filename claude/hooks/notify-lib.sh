#!/bin/bash
# Shared helpers for the Claude Code notification hooks (notify-slack.sh, notify-done.sh,
# notify-session-start.sh). Centralizes secret sourcing, the Slack/ntfy posts, and parsing
# the hook's stdin JSON. See claude/README.md.

# Pull secrets from a non-login-shell-safe fallback file if present (env/~/.localrc wins).
[ -f "$HOME/.claude/secrets.env" ] && source "$HOME/.claude/secrets.env"

# Per-session naming (path it started in + start time), shared with the statusline.
source "$(dirname "${BASH_SOURCE[0]}")/session-name.sh"

# Self-contained GitHub-Markdown -> Slack mrkdwn converter (stdlib Python, no deps). Embedded as a
# heredoc so the single symlinked notify-lib.sh stays portable. Reads stdin, writes converted stdout.
# Fenced/inline code passes through untouched; Slack supports ``` and `code`.
read -r -d '' MD_TO_MRKDWN_PY <<'PYEOF' || true
import re, sys

BOLD = "\x00"  # sentinel so bold markers survive the *italic* pass, restored to * at the end

def inline(seg):
    seg = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r"<\2|\1>", seg)   # ![alt](url) -> <url|alt>
    seg = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<\2|\1>", seg)    # [text](url) -> <url|text>
    seg = re.sub(r"\*\*(.+?)\*\*", BOLD + r"\1" + BOLD, seg)     # **bold**
    seg = re.sub(r"__(.+?)__", BOLD + r"\1" + BOLD, seg)          # __bold__
    seg = re.sub(r"(?<!\*)\*(?!\*)(.+?)\*", r"_\1_", seg)         # *italic* -> _italic_ (Slack)
    seg = re.sub(r"~~(.+?)~~", r"~\1~", seg)                      # ~~strike~~ -> ~strike~
    return seg.replace(BOLD, "*")

def codeaware(text):  # convert only the non-`inline code` segments of a line
    parts = re.split(r"(`[^`]+`)", text)
    return "".join(p if i % 2 else inline(p) for i, p in enumerate(parts))

def conv_line(line):
    m = re.match(r"^#{1,6}\s+(.*)$", line)                       # heading -> bold line
    if m:
        return "*" + codeaware(m.group(1).rstrip()) + "*"
    m = re.match(r"^([ \t]*)[-*+]\s+(.*)$", line)                # bullet -> • (◦ when nested)
    if m:
        indent = m.group(1).replace("\t", "  ")
        pad = " " * len(indent)                             # NBSP: Slack keeps these, unlike plain spaces
        return pad + ("◦ " if indent else "• ") + codeaware(m.group(2))
    if re.match(r"^\s*([-*_])\1{2,}\s*$", line):                 # horizontal rule -> line of dashes
        return "─" * 20
    return codeaware(line)

def convert(md):
    out, fence = [], False
    for line in md.split("\n"):
        if line.lstrip().startswith("```"):                     # fence toggle; drop any info string
            fence = not fence
            out.append("```")
            continue
        out.append(line if fence else conv_line(line))
    return "\n".join(out)

sys.stdout.write(convert(sys.stdin.read()))
PYEOF

# read_hook_context: reads the hook's stdin JSON once and sets globals DIR, LABEL, SID, TRANSCRIPT.
#   DIR        = basename of .cwd (or $PWD if absent)
#   SID        = first 6 chars of .session_id (may be empty)
#   TRANSCRIPT = .transcript_path (path to the session JSONL; may be empty)
#   LABEL      = $CLAUDE_LABEL > meaningful tmux window name > DIR, sanitized for HTTP headers
read_hook_context() {
  local input cwd full_sid
  input="$(cat)"
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
  full_sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
  # shellcheck disable=SC2034  # SID is a global consumed by the sourcing script
  SID="$(printf '%s' "$full_sid" | cut -c1-6)"
  # shellcheck disable=SC2034  # TRANSCRIPT is a global consumed by the sourcing script
  TRANSCRIPT="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
  DIR="$(basename "${cwd:-$PWD}")"
  # Per-session name shared with the statusline. Replaces the old tmux window-name label, which was shared across panes
  # and collided when several Claude sessions ran in one window. CLAUDE_LABEL still overrides.
  if [ -n "${CLAUDE_LABEL:-}" ]; then
    LABEL="$CLAUDE_LABEL"
  else
    LABEL="$(session_name "$TRANSCRIPT" "$full_sid" "$cwd")"
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

# md_to_mrkdwn <github-markdown> -> Slack mrkdwn. Falls back to the input unchanged if python3 is
# missing or the converter errors, so a notification is never dropped over formatting.
md_to_mrkdwn() {
  local text="${1:-}" out
  command -v python3 >/dev/null 2>&1 || { printf '%s' "$text"; return; }
  out=$(printf '%s' "$text" | python3 -c "$MD_TO_MRKDWN_PY" 2>/dev/null) && printf '%s' "$out" || printf '%s' "$text"
}

# chunk_text <text> [max] -> prints <text> split into <=max-char pieces, pieces separated by a US (\x1f)
# byte. Breaks on newline boundaries so markdown stays intact; hard-splits any single line longer than max.
# Default max is 2900, just under Slack's 3000-char-per-mrkdwn-block limit.
chunk_text() {
  local text="${1:-}" max="${2:-2900}" line cur="" started=""
  local US=$'\x1f'
  while IFS= read -r line || [ -n "$line" ]; do
    while [ "${#line}" -gt "$max" ]; do                 # a lone line longer than max -> hard-split it
      [ -n "$cur" ] && { printf '%s%s' "$cur" "$US"; cur=""; }
      printf '%s%s' "${line:0:max}" "$US"
      line="${line:max}"
    done
    if [ -z "$started" ]; then
      cur="$line"; started=1                            # first line seeds the buffer (even if empty)
    elif [ $(( ${#cur} + 1 + ${#line} )) -le "$max" ]; then
      cur="${cur}"$'\n'"${line}"                         # fits -> append, preserving the newline
    else
      printf '%s%s' "$cur" "$US"; cur="$line"            # would overflow -> flush and start a new chunk
    fi
  done <<< "$text"
  printf '%s' "$cur"
}

# slack_send <markdown-text> <project-label>
#   0 = delivered | 1 = not configured (placeholder) | 2 = configured but POST failed
# Long text is chunked into one section block per <=2900-char piece (Slack caps mrkdwn blocks at 3000
# chars and messages at 50 blocks); we keep <=49 section blocks and flag truncation past that.
slack_send() {
  local text="${1:-}" project="${2:-}" url payload
  url="${SLACK_WEBHOOK_URL:-YOUR_SLACK_WEBHOOK_URL}"
  [[ "$url" == https://hooks.slack.com/services/* ]] || return 1
  payload=$(chunk_text "$text" | jq -Rs --arg project "$project" '
    (split("\u001f") | map(select(length > 0) | { type: "section", text: { type: "mrkdwn", text: . } })) as $secs
    | { blocks: (
        $secs[0:49]
        + (if ($secs | length) > 49 then [ { type: "context", elements: [ { type: "mrkdwn", text: "… (truncated)" } ] } ] else [] end)
        + [ { type: "context", elements: [ { type: "mrkdwn", text: ("*Project:* " + $project) } ] } ]
      ) }')
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
