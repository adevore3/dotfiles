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

- `claude_resume` — pick from the 25 most recent sessions
- `claude_resume -n 40` — widen the list
- `claude_resume <substr>` / `-f <substr>` — keep sessions whose title *or* directory matches
- `claude_resume -fs|--find-session <substr>` — match the title only
- `claude_resume -fd|--find-dir <substr>` — match the directory only (`~/dotfiles` and `/home/…/dotfiles` both work)
- `claude_resume -hl|--highlight <substr>` — mark matches in the title/directory cells (bold magenta) without
  filtering; pairs well with a big `-n` when you want context around the hits

Searches are case-insensitive substrings and combine with AND; `-n` caps what survives filtering. Options may come
before or after the positional filter. Color (highlight, zebra stripes, status/token colors) is suppressed when stdout
is not a terminal.

Sessions live as `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`; the dir name is a lossy `/`→`-` of the
cwd, so the authoritative cwd is the `cwd` field inside the transcript. Useful after a stop — see
[[vm-scheduled-autostop]].
