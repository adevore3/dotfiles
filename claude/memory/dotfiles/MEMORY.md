# Memory index

- [One commit per feature](one-commit-per-feature.md) — squash WIP/fixup commits into a single feature commit before the user pushes (unpushed only)
- [No Co-Authored-By](no-co-authored-by.md) — never add the Co-Authored-By trailer to commit messages
- [Pre-push hook needs a pty](pre-push-hook-needs-a-pty.md) — pushing master reads /dev/tty; answer it with `script -qec`
- [Cross-platform handoff relay](cross-platform-handoff-relay.md) — Linux and macOS sessions trade committed files in `claude/handoffs/`; delete theirs, write yours
- [Verify the other session's claims](verify-the-other-sessions-claims.md) — a handoff is a claim, not a fact; three arrived confidently wrong
