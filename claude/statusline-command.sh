#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
sid=$(echo "$input" | jq -r '.session_id // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

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

printf "[%s] %s λ %s(%s%s)" \
    "$sname" \
    "$host" \
    "$node_info" \
    "$cwd" \
    "$git_info"
