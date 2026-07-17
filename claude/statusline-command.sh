#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
sid=$(echo "$input" | jq -r '.session_id // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')

# Per-session name: "<parent>/<leaf> @ <start-time>" from the transcript (path it started in + start time). Shared with
# the Slack notification hooks via session-name.sh.
source ~/.claude/hooks/session-name.sh
sname=$(session_name "$transcript" "$sid" "$cwd")

# Hostname (short)
host=$(hostname -s)

# Node version (matching node_version_prompt)
node_info=""
if command -v node &>/dev/null; then
    node_ver=$(node --version 2>/dev/null)
    node_info="|${node_ver}| "
fi

# Git info: short SHA + branch + dirty/clean state
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    sha=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [[ -n $(git -C "$cwd" status -s --ignore-submodules 2>/dev/null | grep -v '^#') ]]; then
        state="*"
    else
        state=""
    fi
    git_info=" ${sha} ${branch}${state}"
fi

# Context window usage: computed from the transcript's last assistant `usage` (ground truth, version-independent). The
# full window occupancy the model was sent = input + cache_creation + cache_read. Auto-compact is off in settings, so
# this warns before the hard context limit ends the session. Read from the tail so it stays fast on large transcripts.
ctx_info=""
if [[ -n "$transcript" && -f "$transcript" ]]; then
    # Nominal window: 1M for the [1m] extended-context models, else the 200k default.
    if [[ "$model_id" == *"1m"* ]]; then limit=1000000; else limit=200000; fi
    used=$(tac "$transcript" 2>/dev/null | grep -m1 '"usage"' \
        | jq -r '(.message.usage // {}) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null)
    if [[ -n "$used" && "$used" =~ ^[0-9]+$ && "$used" -gt 0 ]]; then
        pct=$(( used * 100 / limit ))
        # Color by absolute token count (auto-compact is off, so these are the real warning lines):
        #   <100k green, >100k yellow, >200k orange, >300k light red, >500k dark red.
        if   (( used >= 500000 )); then color=$'\033[38;5;88m'   # dark red
        elif (( used >= 300000 )); then color=$'\033[38;5;203m'  # light red
        elif (( used >= 200000 )); then color=$'\033[38;5;208m'  # orange
        elif (( used >= 100000 )); then color=$'\033[33m'        # yellow
        else                           color=$'\033[32m'; fi     # green
        reset=$'\033[0m'
        # Humanize used tokens to k/M.
        if   (( used >= 1000000 )); then hused=$(awk "BEGIN{printf \"%.1fM\", $used/1000000}")
        else                             hused=$(( used / 1000 ))k; fi
        if (( limit >= 1000000 )); then hlimit=$(( limit / 1000000 ))M; else hlimit=$(( limit / 1000 ))k; fi
        ctx_info=" ${color}ctx:${pct}% (${hused}/${hlimit})${reset}"
    fi
fi

printf "[%s] %s λ %s(%s%s)%s" \
    "$sname" \
    "$host" \
    "$node_info" \
    "$cwd" \
    "$git_info" \
    "$ctx_info"
