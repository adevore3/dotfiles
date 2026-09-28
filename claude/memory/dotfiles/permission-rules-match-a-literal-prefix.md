---
name: permission-rules-match-a-literal-prefix
description: "Bash permission rules match a literal command prefix, so a flag before the subcommand defeats both allow and deny"
metadata:
  node_type: memory
  type: project
  originSessionId: 84336bbb-a3e2-414e-bbb5-e1484b3d0531
  modified: 2026-09-28T19:05:05.815Z
---

A `Bash(...)` rule in `settings.json` matches the **literal leading text** of the command string. Two consequences that
decide how the allowlist has to be written, both hit while building the current `claude/settings.json`:

- **A flag placed ahead of the subcommand defeats verb-level rules, allow *and* deny alike.** This repo invokes the AWS
  CLI as `aws --profile <name> <service> <verb>`, so `Bash(aws s3 rm:*)` never matches a profiled call — and neither
  would a deny spelled the same way. That is why `aws` is allowed bare rather than scoped: scoping it would mean
  per-profile rules, which gate nothing *inside* a profile. Re-check the calling convention with
  `grep -rhoE '\baws [a-z0-9-]+ [a-z0-9-]+' --include='*.sh' --include='*.func' --include='*.md' .` before assuming a
  verb rule will fire.
- **A wrapper command escapes the rule entirely.** `script -qec 'git push ...'` starts with `script`, so `Bash(git:*)`
  does not cover it. That is the exact form [[pre-push-hook-needs-a-pty]] requires for pushing master here, so that push
  still prompts. Do not "fix" this by allowing `Bash(script -qec:*)` — that would allow arbitrary commands through the
  wrapper and void the whole allowlist.

Also settled while writing this config: `deny` is a **hard block**, not a prompt — it cannot be overridden by an allow
rule, and the command becomes unrunnable until the settings file is edited. When the goal is "make it ask", the buckets
are `ask` or simply leaving the command unlisted. What remains **unverified**: whether an `ask` rule overrides a
matching `allow` rule. The current file avoids the question by never listing the same command in both.

See [[prefers-bare-permission-rules]] for which shape to reach for first.
