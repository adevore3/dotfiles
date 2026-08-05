---
name: verify-the-other-sessions-claims
description: Re-verify another session's platform claims before building on them; several arrived confidently wrong
metadata:
  type: feedback
---

A result relayed from a session on the other host is a claim, not a fact. Re-derive anything you are about to build
on, and say plainly when a premise turns out wrong rather than working around it quietly.

**Why:** three cases during the macOS port, each stated with confidence and each false.

- A retire step using `ssh-agent -k` was a no-op: `-k` kills whatever `SSH_AGENT_PID` names and ignores
  `SSH_AUTH_SOCK` entirely, so a fresh shell printed "SSH_AGENT_PID not set" and the following `rm` orphaned a live
  agent. Only running it caught that.
- The other session asserted `SSH_AGENT_DISABLE` was set on the cloudvm. It is unset there, absent from `~/.localrc`, and
  appears nowhere in the repo outside two comments — a comment was mistaken for configuration.
- I wrote that a portability catch "got a line in CLAUDE.md" without looking. It had not; I added the line rather
  than softening the sentence.

**How to apply:** run the thing rather than reading it. Where your platform makes that impossible, say so and hand
the check back explicitly — do not assert it works. See [[cross-platform-changes-need-both-hosts]].
