# Global Claude Code Instructions

## Tool Permissions — MUST FOLLOW
- **NEVER ask permission for read-only operations.** Just do them. This includes: reading files, glob, grep, bash commands for searching/reading (ls, git log, git diff, git status, cat, head, tail, find), and web searches. Do NOT say "Let me read this file" and wait — just read it.
- **Under `~/`, write freely.** File edits, code changes, running builds/tests — do these without asking.
- **Always ask before destructive commands** (force push, reset --hard, rm -rf, branch deletion) regardless of context.

## Git Workflow — MUST FOLLOW
- **Always pull/fetch the default branch (main/master) before starting branch work, and branch from an up-to-date
  tip.** Before pushing, rebasing, or opening an MR, re-sync with the latest default branch too. This avoids landing
  changes that conflict with work already merged — especially an overlapping fix touching the same file/ticket.

## Secrets & Credentials — MUST FOLLOW
- **A secret's literal text must NEVER appear in a command you emit.** Tool calls are recorded in the
  transcript. This includes passwords, API tokens, and Basic-auth blobs (base64 is reversible, so an
  encoded credential is still the secret).
- **Reference credentials indirectly.** Keep them in a mode-600 file the user authored (e.g. a netrc
  file) or an env var; pass them by path/name only. Never `cat`/`echo`/`grep`/print a credential file.
- **For `curl` with auth:** prefer `--netrc-file <path>` (keeps the secret out of `argv` entirely).
  Never use `-v`/`--trace`/`--trace-ascii` (they dump the `Authorization` header); use `-sS`.
- The user creates/edits the credential file in their OWN terminal — not via you, and not via the `!`
  session prefix (both would record the secret).

## Communication Style
- Be concise. Don't summarize what you just did — I can read the diff.
- Don't narrate your thought process or explain obvious steps.
- Skip preamble like "Great question!" or "Sure, I can help with that."
- When asking clarifying questions, keep them short and specific.

## Code Style
- **Comments and prose wrap at 120 characters, not 80.** Applies to every source language (Bash, Gradle/Groovy, Java/Scala, Python, YAML, HCL, Makefiles, Dockerfile, etc.) AND to markdown doc files (READMEs) — column-wrap markdown prose at 120 too; do not leave one-paragraph-per-line. Keep the prose itself terse — width is for fewer wrap points, not longer sentences. Leave unwrappable constructs alone: markdown table rows, long URLs, and single long tokens (e.g. fully-qualified config keys).

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
