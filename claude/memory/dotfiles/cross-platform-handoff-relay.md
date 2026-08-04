---
name: cross-platform-handoff-relay
description: Cross-platform work here runs as a two-session relay through committed files in claude/handoffs/
metadata:
  type: project
---

Linux/macOS work on this repo is split between two Claude sessions — one on the headless cloudvm, one on the user's
MacBook — because neither host can test the other's platform and BSD semantics cannot be faked from Linux. They
coordinate through markdown in `claude/handoffs/`, committed and pushed. The user relays it: "the mac session left
you a handoff."

The protocol, as practiced through the July–August 2026 macOS port (8 handoffs, squashed into one commit on
2026-08-04): read their file, verify its claims on your own platform, fix what is wrong, **delete their file**, write
a new one naming what you changed and what you want checked, then commit and push. A handoff still sitting in the
tree means that session owes a reply — `claude/handoffs/` should be empty at rest.

Don't stall waiting on a reply. Do everything testable locally and put only the genuinely platform-blocked items in
the handoff. See [[verify-the-other-sessions-claims]].
