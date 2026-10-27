#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
sid=$(echo "$input" | jq -r '.session_id // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

# Per-session name: "<parent>/<leaf> @ <start-time>" from the transcript (path it started in + start time), with $HOME
# shown as ~. Shared with the Slack notification hooks via session-name.sh.
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
    # Worktree label: the worktree root's basename (stable across `cd` into subdirs, unique per worktree). Lets you
    # tell parallel sessions apart at a glance when several run in different worktrees of one repo.
    wt=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    wt_info=""
    [[ -n "$wt" ]] && wt_info=" ⑃ $(basename "$wt")"
    git_info=" ${sha} ${branch}${state}${wt_info}"
fi

# Context window usage: computed from the transcript's last assistant `usage` (ground truth, version-independent). The
# full window occupancy the model was sent = input + cache_creation + cache_read. Auto-compact is off in settings, so
# this warns before the hard context limit ends the session. Read from the tail so it stays fast on large transcripts.
ctx_info=""
if [[ -n "$transcript" && -f "$transcript" ]]; then
    # Window size as Claude Code reports it; when it isn't sent, show ?? rather than guess one.
    limit=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
    [[ "$limit" =~ ^[0-9]+$ && "$limit" -gt 0 ]] || limit=""
    used=$(tac "$transcript" 2>/dev/null | grep -m1 '"usage"' \
        | jq -r '(.message.usage // {}) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null)
    if [[ -n "$used" && "$used" =~ ^[0-9]+$ && "$used" -gt 0 ]]; then
        # Color by absolute token count (auto-compact is off, so these are the real warning lines):
        #   <200k green, >200k yellow, >400k orange, >600k light red, >800k dark red.
        if   (( used >= 800000 )); then color=$'\033[38;5;88m'   # dark red
        elif (( used >= 600000 )); then color=$'\033[38;5;203m'  # light red
        elif (( used >= 400000 )); then color=$'\033[38;5;208m'  # orange
        elif (( used >= 200000 )); then color=$'\033[33m'        # yellow
        else                           color=$'\033[32m'; fi     # green
        reset=$'\033[0m'
        # Humanize used tokens to k/M.
        if   (( used >= 1000000 )); then hused=$(awk "BEGIN{printf \"%.1fM\", $used/1000000}")
        else                             hused=$(( used / 1000 ))k; fi
        if   [[ -z "$limit" ]];      then pct="??"; hlimit="???"
        elif (( limit >= 1000000 )); then pct=$(( used * 100 / limit )); hlimit=$(( limit / 1000000 ))M
        else                              pct=$(( used * 100 / limit )); hlimit=$(( limit / 1000 ))k; fi
        ctx_info=" ${color}ctx:${pct}% (${hused}/${hlimit})${reset}"
    fi
fi

# Display only: $cwd itself stays absolute above, since `git -C` and session_name need the real path. The prefix test
# is anchored on "$HOME" or "$HOME/" so a sibling like /home/adevore2 is left alone instead of becoming "~2".
disp_cwd="$cwd"
[[ "$cwd" == "$HOME" || "$cwd" == "$HOME"/* ]] && disp_cwd="~${cwd#"$HOME"}"

printf "[%s] %s λ %s(%s%s)%s" \
    "$sname" \
    "$host" \
    "$node_info" \
    "$disp_cwd" \
    "$git_info" \
    "$ctx_info"
