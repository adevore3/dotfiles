---
name: cross-platform-changes-need-both-hosts
description: Shell/date/sed/ssh changes here are unverified until run on both the Linux cloudvm and the MacBook
metadata:
  type: project
---

Anton runs this repo on two hosts — a headless Linux cloudvm and a MacBook — and a change to date/sed/stat/ssh or
shell startup is not verified until it has run on both. BSD behavior cannot be faked from Linux: stub executables on
a synthetic PATH catch flag *spelling* but not semantics, which is how BSD `date -j -f` accepting a partial match and
`ps -o ucomm=` right-padding both got through review. Say which host you actually tested on and hand the rest back
rather than asserting it works.

The July–August 2026 macOS port ran a session per host with Anton relaying between them. The markdown it passed
through `claude/handoffs/` was a scratch mechanism for that round trip, not a convention — the directory was deleted
once the port landed. Don't recreate it; durable findings belong here or in CLAUDE.md's portability section.

See [[verify-the-other-sessions-claims]].
