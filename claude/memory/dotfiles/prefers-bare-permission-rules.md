---
name: prefers-bare-permission-rules
description: Anton prefers one broad permission rule over an enumerated narrow list; offer the bare option first
metadata:
  node_type: memory
  type: feedback
  originSessionId: 84336bbb-a3e2-414e-bbb5-e1484b3d0531
  modified: 2026-09-28T19:05:16.770Z
---

When adding a tool to the permissions allowlist, lead with the bare `Bash(<cmd>:*)` form rather than an enumerated list
of safe subcommands. Anton picked bare for `aws` after being shown that it leaves prod deletes ungated, and then asked
to collapse a hand-built list of ~30 `git` rules — including a `git branch -d` / `-D` split he had requested one turn
earlier — down to a single `Bash(git:*)`.

**Why:** the enumerated form buys less safety than it looks like it does (see
[[permission-rules-match-a-literal-prefix]]) and costs a prompt every time a verb was not anticipated. He would rather
absorb the risk than maintain the list.

**How to apply:** propose the bare rule, state in one or two sentences what it leaves ungated — especially anything in
the CLAUDE.md destructive-command list (force push, `reset --hard`, `rm -rf`, branch deletion) — and then write it. Do
not open an AskUserQuestion weighing bare-vs-enumerated; that fork has been settled twice. Record the reasoning in the
commit body so the next reader does not "harden" it back into an enumeration. If the narrow form is genuinely the only
thing that works, say so plainly rather than offering it as a co-equal option.
