---
name: mr-voice
description: "When writing MR/PR text — use my-voice for human-facing comments/replies, own voice for descriptions and bot replies"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b931fa0c-597d-4cd1-8e49-485a33aed1ca
---

When writing to MRs/PRs: comments or replies directed at **other people** must use the `my-voice` skill so
they read as Anton. MR **descriptions**, and replies to **CodeRabbit or any other AI/bot**, can use my own voice.

**Why:** human-facing review conversation should sound like Anton; bot-facing and self-authored description text
doesn't need his personal voice.

**How to apply:** before drafting a human-directed comment/reply on an MR, invoke `my-voice`. For the MR
description or a reply to a bot reviewer, write directly without the skill.
