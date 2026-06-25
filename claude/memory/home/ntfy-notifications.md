---
name: ntfy-notifications
description: User prefers outbound-only phone notifications via ntfy.sh Stop hook; rejected inbound bridge due to threat-model concerns with dontAsk mode.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6d402d95-7a41-479b-bbc8-fef99af333b3
---

For phone/Slack/etc. notification integrations with Claude Code, default to **outbound-only** patterns (Stop hook, Notification hook posting to a webhook). Do not propose inbound bridges (phone → tmux send-keys, etc.) without first surfacing the threat model.

**Why:** User considered an inbound ntfy → tmux send-keys bridge, with a shared PIN as auth. Rejected it because the Claude session runs `dontAsk` permission mode on an AWS dev VM (Read/Glob/Grep/Bash/Edit/Write all auto-allowed). With a public ntfy.sh topic, anyone who learns topic + PIN can inject prompts that I will execute — effectively reducing the session's security to a ~20-bit shared secret, with blast radius covering file reads (~/.ssh, ~/.aws), arbitrary bash, and credential exfiltration. Self-hosting ntfy on the same VM was also considered and rejected as too operationally complex (public ingress, TLS, iOS APNs relay).

**How to apply:**
- Default proposal for new notification needs: outbound webhook (Stop hook firing curl).
- If user asks for inbound control from phone, name the threat model up front. Suggest SSH from a phone client (Termius/Blink/Prompt) as the proper-auth alternative.
- Current setup lives at `~/.claude/hooks/notify-done.sh` and posts to ntfy.sh topic `claude-adevore-a134a5a6fe1bc811` (treat the topic like a secret — anyone with it can read outbound pings). Reuse this topic for additional outbound hooks (e.g. Notification hook for permission prompts) unless user wants per-purpose topics.
- If sensitive data could end up in outbound messages, revisit: ntfy.sh is public infrastructure, messages traverse their server in plaintext over TLS but are stored on disk for a few hours before expiry.

**Per-session labeling (final configuration):** the script resolves the notification title with priority `$CLAUDE_LABEL` env var → meaningful tmux window name (skipping defaults like `bash`/`zsh`/numeric) → cwd basename. Body always includes `Done in <cwd-basename> · <session-id-prefix>` for absolute differentiation. To distinguish concurrent sessions on the phone, user launches with `CLAUDE_LABEL=projectname claude` per session. Empirically, settings.json hook changes are hot-loaded — new Stop hook entries fire in already-running sessions without restart.

**Writes under `~/.claude/` are blocked by the harness even in dontAsk mode** (config-injection guardrail). For any edits to `~/.claude/settings.json` or `~/.claude/hooks/*`, give the user commands to run themselves with the `!` prefix (or vim with `:set paste` for multi-line script content) rather than attempting Write/Edit/Bash directly. The memory dir at `~/.claude/projects/-home-adevore/memory/` *is* writable.
