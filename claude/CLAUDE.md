# Global Claude Code Instructions

## Tool Permissions — MUST FOLLOW
- **NEVER ask permission for read-only operations.** Just do them. This includes: reading files, glob, grep, bash commands for searching/reading (ls, git log, git diff, git status, cat, head, tail, find), and web searches. Do NOT say "Let me read this file" and wait — just read it.
- **Under `~/`, write freely.** File edits, code changes, running builds/tests — do these without asking.
- **Always ask before destructive commands** (force push, reset --hard, rm -rf, branch deletion) regardless of context.

## Communication Style
- Be concise. Don't summarize what you just did — I can read the diff.
- Don't narrate your thought process or explain obvious steps.
- Skip preamble like "Great question!" or "Sure, I can help with that."
- When asking clarifying questions, keep them short and specific.

## Code Style
- **Comments wrap at 120 characters, not 80.** Applies to every source language (Bash, Gradle/Groovy, Java/Scala, Python, YAML, HCL, Makefiles, Dockerfile, etc.). Keep the prose itself terse — width is for fewer wrap points, not longer sentences. Markdown doc files keep one paragraph per line and don't need column wrapping.

## User Environment
- Shell: bash with vi mode
- Dotfiles: `~/dotfiles/` managed by dotbot, with modular bash functions, tmux, vim, git configs
- Logging utilities available: `log_debug`, `log_info`, `log_warn`, `log_error` (from dotfiles)
- Uses autojump for directory navigation
- DOTFILES env var points to dotfiles repo root

## Notifications
- When your reply needs the user to make a decision or answer a question before you can
  continue, end the message with `<!-- needs-input -->` (an HTML comment that stays hidden in
  the terminal). A Stop hook reads it to flag the phone/Slack notification as needing input.
