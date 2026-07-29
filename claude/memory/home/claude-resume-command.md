---
name: claude-resume-command
description: "claude_resume dotfiles function — pick a recent Claude session, cd to its dir, resume it"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 68fc3c1f-34d3-4da7-ba74-9dfc84e0efc7
---

`claude_resume` (alias `cr`) lists recent Claude Code sessions (newest first), each with its real cwd and title read
from the transcript, then `cd`s into the chosen session's directory and runs `claude --resume <id>` — so you are left
in that directory when the session exits. Run it from anywhere. Two pieces:

- `claude/functions/claude_resume.func` — thin shell wrapper, auto-sourced by the bashrc `*.func` loop. Exists only
  because a child process cannot cd its parent: it runs the picker, reads the pick back from a temp file, cds, resumes.
- `claude/functions/claude_resume.py` — the picker: scanning, filtering, live detection, table rendering, the prompt.
  Reports the pick via `--result-file` (session id on line 1, absolute directory on line 2). Tests in
  `claude/test/claude_resume_test.py`, driven by `claude_resume_test.sh` so `make test` picks them up.

- `claude_resume` — pick from the 25 most recent sessions
- `claude_resume -n 40` — widen the list
- `claude_resume <substr>` / `-f <substr>` — keep sessions whose title *or* directory matches
- `claude_resume -fs|--find-session <substr>` — match the title only
- `claude_resume -fd|--find-dir <substr>` — match the directory only (`~/dotfiles` and `/home/…/dotfiles` both work)
- `claude_resume -hl|--highlight <substr>` — mark matches in the title/directory cells (bold magenta) without
  filtering; pairs well with a big `-n` when you want context around the hits
- `claude_resume -l|--list` — print the table and stop: no prompt, nothing resumed, so it is safe to pipe
  (`cr -l -n 50 | grep spark`)
- `claude_resume -c|--clean` — delete the sessions whose launch directory no longer exists (status `gone` in the
  table), after a y/N confirmation. Removes each transcript plus its `<session-id>/` sidecar dir, then any project dir
  left without a transcript. Filters apply, `-n` does not; add `-l` for a dry run. A session held open by a running
  `claude` is never deleted.

Searches are case-insensitive substrings and combine with AND; `-n` caps what survives filtering. Options may come
before or after the positional filter. Color (highlight, zebra stripes, status/token colors) is suppressed when stdout
is not a terminal. The Directory column shows the whole `~`-abbreviated path when it fits and drops leading
components with a `…/` prefix only when it does not.

Sessions live as `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`; the dir name is a lossy `/`→`-` of the
cwd, so the authoritative cwd is the `cwd` field inside the transcript. Useful after a stop — see
[[vm-scheduled-autostop]].
