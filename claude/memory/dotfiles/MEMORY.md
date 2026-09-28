# Memory index

- [One commit per feature](one-commit-per-feature.md) — squash WIP/fixup commits into a single feature commit before the user pushes (unpushed only)
- [No Co-Authored-By](no-co-authored-by.md) — never add the Co-Authored-By trailer to commit messages
- [Pre-push hook needs a pty](pre-push-hook-needs-a-pty.md) — pushing master reads /dev/tty; answer it with `script -qec`
- [Cross-platform changes need both hosts](cross-platform-changes-need-both-hosts.md) — unverified until run on the cloudvm *and* the MacBook; stubs catch flag spelling, not semantics
- [Verify the other session's claims](verify-the-other-sessions-claims.md) — a relayed result is a claim, not a fact; three arrived confidently wrong
- [Permission rules match a literal prefix](permission-rules-match-a-literal-prefix.md) — a flag before the subcommand defeats allow *and* deny; deny is a hard block, not a prompt
- [Prefers bare permission rules](prefers-bare-permission-rules.md) — lead with `Bash(cmd:*)`, flag what it ungates, don't re-open the bare-vs-enumerated fork
