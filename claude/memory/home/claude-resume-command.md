---
name: claude-resume-command
description: "claude_resume dotfiles function — pick a recent Claude session, cd to its dir, resume it"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 68fc3c1f-34d3-4da7-ba74-9dfc84e0efc7
---

`claude_resume` is a bash function at `~/dotfiles/claude/functions/claude_resume.func` (auto-sourced by the
bashrc `*.func` loop). Run from anywhere: it lists recent Claude Code sessions (newest last, by the prompt),
each with its real cwd + first-prompt title read from the transcript, then `cd`s into the chosen session's
directory and runs `claude --resume <id>`.

- `claude_resume` — pick from the 20 most recent sessions
- `claude_resume <substr>` — filter to sessions whose cwd contains the substring
- `claude_resume -n 40` — widen the list

Sessions live as `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`; the dir name is a lossy `/`→`-` of the
cwd, so the authoritative cwd is the `cwd` field inside the transcript. Useful after a stop — see
[[vm-scheduled-autostop]].
