# Global Claude Code Instructions

## Tool Permissions — MUST FOLLOW
- **NEVER ask permission for read-only operations.** Just do them. This includes: reading files, glob, grep, bash commands for searching/reading (ls, git log, git diff, git status, cat, head, tail, find), and web searches. Do NOT say "Let me read this file" and wait — just read it.
- **Under `~/`, write freely.** File edits, code changes, running builds/tests — do these without asking.
- **Always ask before destructive commands** (force push, reset --hard, rm -rf, branch deletion) regardless of context.

## Git Workflow — MUST FOLLOW
- **An up-to-date default branch is a hard pre-req for starting any new work.** Before fetching or fast-forwarding
  anything, confirm the working tree is clean (`git status --short`) and nothing is unpushed (`git log --branches
  --not --remotes --oneline`). If there are uncommitted or unpushed changes, stop and ask — never stash, commit,
  discard, or force anything to clear the way. Then, before creating a branch or worktree, `git fetch --prune origin`
  and fast-forward the default branch (main/master); never branch from a stale local tip.
  Confirm it actually landed (`git status -sb` showing no divergence, or `git rev-list --count HEAD..origin/<default>`
  = 0) instead of assuming the fetch was enough — a main checkout left sitting at a pre-merge commit is the usual case,
  including right after your own MR merges. Re-sync again before pushing, rebasing, or opening an MR. This avoids
  landing changes that conflict with work already merged — especially an overlapping fix touching the same file/ticket.
- **Branch names:** `adevore/<ticket>/<short-description>`, e.g. `adevore/DIRP-XXXX/adding-feature`. Lowercase,
  hyphen-separated description; keep it short.
- **Work in a dedicated worktree — except this repo.** For any repo *other than* the dotfiles repo (`~/dotfiles`) and
  its `indeed/` submodule (`~/dotfiles/indeed`), do the work in a git worktree named to match the branch/ticket rather
  than in the main checkout, e.g. `git worktree add ../<repo>-DIRP-XXXX -b adevore/DIRP-XXXX/<desc>`. This keeps
  parallel sessions isolated (the worktree-awareness hook warns when two sessions would collide on shared local state)
  and the main checkout clean. The dotfiles repo and its `indeed/` submodule are edited in place, not in a worktree.
- **Before cleaning up a worktree, account for its untracked files.** `git worktree remove` deletes the directory, so
  anything untracked or gitignored goes with it and there's no way back. Run `git status --short --ignored` and look at
  what's there, especially `out/` (run logs, captured metadata, test evidence) — that content exists nowhere else. Copy
  anything worth keeping into the main checkout's `out/<ticket>/` first, then confirm before removing the worktree.
- **When a ticket is done, clean up in this order: worktree → branch → default branch.** Trigger is the ticket being
  closed *and* the merge confirmed — verify it (MR state is `merged`, or the commit is reachable from the default
  branch), not just that CI went green. Then: account for untracked files per the bullet above, `git worktree remove
  <path>`, `git branch -d <branch>`, and finally `git fetch --prune` + fast-forward the default branch in the main
  checkout so the next task starts clean. Leaving these behind is exactly what makes the next piece of work branch from
  a stale tip.
- **This standing instruction authorizes that one `git branch -d`** — a merged-branch cleanup after a confirmed merge is
  routine, not something to ask about each time. Use plain `-d` so git refuses if the branch isn't actually merged.
  Everything else in the destructive-command rule still needs asking: `-D`, unmerged branches, and remote deletions.
- **First commit message:** lead with the ticket, e.g. `DIRP-XXXX added feature`, optionally a short body explaining
  the change — keep it terse. GitLab uses the first commit's message as the default squash message on merge, so make it
  the good one. Later commits on the branch can be simpler/one-liners.

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
