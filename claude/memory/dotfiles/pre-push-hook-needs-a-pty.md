---
name: pre-push-hook-needs-a-pty
description: Pushing master in dotfiles fails non-interactively — git/hooks/pre-push reads /dev/tty; answer it through script, whose syntax differs on macOS vs Linux
metadata: 
  node_type: memory
  type: project
  originSessionId: cedb90c0-e2c6-46d6-9436-8c66bf20acbe
  modified: 2026-08-03T18:12:12.952Z
---

`git push origin master` in `~/dotfiles` fails with `git/hooks/pre-push: line 7: /dev/tty: No such device or
address` and `failed to push some refs`. The hook prompts "You're about to push to 'master'. Are you sure?" and
reads `/dev/tty` directly, so piping stdin does not reach it. Non-master branches skip the prompt entirely.
`core.hooksPath` is global (`~/dotfiles/git/hooks`), so the `indeed/` submodule gets the same prompt on master.

**Why:** it is a deliberate guard against unattended pushes to the default branch. Don't reach for `--no-verify`
just to get past it — that also skips any real checks the hook later grows.

**How to apply:** once Anton has asked for the push, give the hook a pty and answer it. `script`'s syntax is not
portable, and whether the answer needs delaying differs too — use the line for the platform you are on:

- **Linux (util-linux 2.39):** `echo y | script -qec 'git push origin master' /dev/null`. No delay needed: the
  `y` waits in the pty buffer until the hook reads it. Verified on three real pushes and against a throwaway
  bare remote, where the same push without a pty fails on `/dev/tty` as described above.
- **macOS (BSD):** `(sleep 2; printf 'y\n'; sleep 2) | script -q /dev/null git push origin master`. BSD `script`
  rejects `-c` and takes the command as trailing argv, and there `echo y |` alone loses the answer. The failure
  is not that the read gets nothing — BSD `script` pushes the EOT into the pty *ahead* of the `y`, so
  `read -n 2` takes `\004` as the first of its two characters and `$REPLY` ends up `\004y`, which the hook's
  `grep -E '^[Yy]$'` rejects. The `^Dy` in the output is literally that. Delaying the answer past the prompt
  leaves `$REPLY` a clean `y`.
- **Don't collapse them into one line.** The BSD spelling on util-linux dies with `script: unexpected number of
  arguments` and pushes nothing; the delayed-answer form does work on Linux, it is just needlessly slow there.

Expect a wall of pty-echoed progress output; the `16dd9b0..3a04c61  master -> master` line is the confirmation.
Verify separately with `git log --oneline origin/master..HEAD | wc -l` after a `git fetch`. Related:
[[one-commit-per-feature]].
