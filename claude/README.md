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
| `hooks/notify-done.sh` | `~/.claude/hooks/notify-done.sh` | Stop hook (done) -> Slack (ntfy opt-in) |
| `hooks/notify-session-start.sh` | `~/.claude/hooks/notify-session-start.sh` | SessionStart hook (notify both + health-warn, async) |
| `hooks/session_coord.sh` | `~/.claude/hooks/session_coord.sh` | Worktree-awareness hook (PreToolUse/PostToolUse) |
| `plugins/*.json` | `~/.claude/plugins/*.json` | Manifests only, not plugin code |
| `memory/dotfiles/` | `~/.claude/projects/<slug>/memory/` | Directory symlink (see below) |

Fixed paths are symlinked via `link:` entries in `../install.conf.yaml`. The memory
dir's path depends on the absolute repo path, so it's symlinked by `setup.sh` (run from
a dotbot `shell:` step).

## Notifications

- **Notification** event (Claude needs attention) -> Slack (`notify-slack.sh`), desktop fallback.
- **Stop** event (Claude finished) -> Slack only by default (`notify-done.sh`); set
  `NTFY_FALLBACK=1` to fall back to ntfy on any Slack failure. The Slack message carries
  Claude's **full** last reply, chunked across multiple section blocks (Slack caps blocks at
  3000 chars / 50 blocks); ntfy, when enabled, gets a 200-char snippet. Flags **needs-input**
  (❓, ntfy Priority high) vs **FYI** (✅, ntfy Priority low), classified by a heuristic + the
  `<!-- needs-input -->` marker. Exactly one notification.
- **SessionStart** event -> notifies BOTH channels and warns (in-session + via any working
  channel) if either is unconfigured or fails; never blocks (`notify-session-start.sh`, async).

All hooks share `notify-lib.sh` (`slack_send`, `ntfy_send`, `read_hook_context`, `md_to_mrkdwn`).
Each send helper returns 0=delivered / 1=not configured / 2=failed. Channels skip gracefully when
unset. `md_to_mrkdwn` converts Claude's GitHub-flavored markdown to Slack mrkdwn (stdlib Python,
embedded in `notify-lib.sh`; no-ops to raw text if python3 is missing).

To eyeball the Slack formatting after changing the converter, use `test/notify-preview.sh` with the
saved samples in `test/fixtures/`: run it with no args for an offline converted preview (NBSP shown
as `·`), or `--send` to fire the live Stop hook to Slack. It is not a `*_test.sh`, so `make test`
skips it (it can touch the network).

## Worktree awareness

`hooks/session_coord.sh` (a `PreToolUse`/`PostToolUse` hook) keeps two Claude sessions running in **parallel git
worktrees of one repo** from silently colliding on shared, machine-global state (a local artifact repo, ports, image
tags). When a session starts a watched command, the hook records a claim (one file per worktree+resource under
`${XDG_STATE_HOME:-~/.local/state}/claude-session-coord/`); a second session starting the same class of command gets a
non-blocking warning injected into its context, naming the other worktree, branch, description, and how long it's been
running. Warn-only — nothing is ever blocked. Claims clear on `PostToolUse` and self-heal after a TTL
(`CLAUDE_SESSION_COORD_TTL`, default 3600s).

The engine is generic and carries no project-specific strings: watched commands come from config files dropped into
`~/.claude/session-coord.d/*.conf` (TAB-separated `<resource>\t<extended-regex>\t<hint>`). With no config it's a silent
no-op, so it's safe on any machine. The private `indeed/` submodule supplies the `publocal` and `spark-run` patterns via
its own `setup.sh`.

`session_note "<text>"` (a shell function in `functions/session_note.func`, auto-sourced by bashrc) sets this
worktree's one-line description shown in those warnings; with no note it falls back to the session's transcript summary,
then the branch name. This pairs with the "work in a dedicated worktree" rule in `CLAUDE.md`: give each repo's work its
own worktree and the two sessions stay isolated and mutually aware.

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
