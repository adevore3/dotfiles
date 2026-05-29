# Claude Code config (non-Indeed)

Version-controlled, machine-portable Claude Code config. Installed by dotbot
(`../install`) as **symlinks** from `~/.claude/` back into this directory, so edits
flow both ways automatically. Indeed-specific config lives in the private `indeed/`
submodule, not here.

## Layout

| Path | Symlinked to | Notes |
|------|--------------|-------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions |
| `settings.json` | `~/.claude/settings.json` | Claude Code writes to this at runtime; expect diffs |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | |
| `hooks/notify-lib.sh` | `~/.claude/hooks/notify-lib.sh` | Shared helper sourced by the two hooks |
| `hooks/notify-slack.sh` | `~/.claude/hooks/notify-slack.sh` | Notification hook (attention) |
| `hooks/notify-done.sh` | `~/.claude/hooks/notify-done.sh` | Stop hook (done) -> ntfy + Slack |
| `hooks/notify-session-start.sh` | `~/.claude/hooks/notify-session-start.sh` | SessionStart hook (notify both + health-warn, async) |
| `plugins/*.json` | `~/.claude/plugins/*.json` | Manifests only, not plugin code |
| `memory/dotfiles/` | `~/.claude/projects/<slug>/memory/` | Directory symlink (see below) |

Fixed paths are symlinked via `link:` entries in `../install.conf.yaml`. The memory
dir's path depends on the absolute repo path, so it's symlinked by `setup.sh` (run from
a dotbot `shell:` step).

## Notifications

- **Notification** event (Claude needs attention) -> Slack (`notify-slack.sh`), desktop fallback.
- **Stop** event (Claude finished) -> Slack preferred, ntfy fallback (`notify-done.sh`). The
  message includes a snippet of Claude's last reply and flags **needs-input** (❓, ntfy
  Priority high) vs **FYI** (✅, ntfy Priority low), classified by a heuristic + the
  `<!-- needs-input -->` marker. Exactly one notification.
- **SessionStart** event -> notifies BOTH channels and warns (in-session + via any working
  channel) if either is unconfigured or fails; never blocks (`notify-session-start.sh`, async).

All hooks share `notify-lib.sh` (`slack_send`, `ntfy_send`, `read_hook_context`). Each send
helper returns 0=delivered / 1=not configured / 2=failed. Channels skip gracefully when unset.

## Memory

`memory/dotfiles/` is a **directory** symlink, so any new memory file Claude Code writes
lands in this repo's working tree and shows up as an untracked file in `git status`.
Commit it, leave it, or add it to `.gitignore` — your call.

To track another repo's memory: create `memory/<repo>/` and add a line to `setup.sh`.

## Secrets

Secrets are never committed. Each hook reads its secret from the environment, falling
back to a placeholder that makes the hook no-op safely. Provide the real value in either:

1. `~/.localrc` (primary) — `export VAR=...`; sourced by bashrc, `chmod 600`, untracked.
2. `~/.claude/secrets.env` (fallback) — `export VAR=...`; sourced by `notify-lib.sh`,
   for when Claude Code is launched outside an interactive shell (IDE, systemd, cron).

| Secret | Env var | Placeholder in repo |
|--------|---------|---------------------|
| Slack webhook | `SLACK_WEBHOOK_URL` | `YOUR_SLACK_WEBHOOK_URL` |
| ntfy topic | `NTFY_TOPIC` | `claude-CHANGEME` |
