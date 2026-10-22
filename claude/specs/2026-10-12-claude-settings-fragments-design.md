# Claude settings: fragment merge

Design, 2026-10-12. Splits `~/.claude/settings.json` into tracked fragments so Indeed-specific content lives in the
private `indeed/` submodule and never reaches this public repository.

**This file is in the public repo.** It names categories of sensitive content, never the values. Do not paste an
account ID, internal hostname, role name, or repo path into this document — that is the exact disclosure the design
exists to prevent.

## Why

`install.conf.yaml` symlinked `~/.claude/settings.json` into this repository with `force: true`. This repository is
public (`gh`/API: `private=false, visibility=public`). Claude Code *writes* to that path — `/config`, `/model`, and
the auto-mode environment survey all land there — so every harness write flowed into a public repo.

That is not hypothetical. On 2026-10-12 the working tree held an uncommitted addition to `claude/settings.json`
containing the `autoMode.environment` block: AWS account IDs for two environments, an internal Terraform Cloud host
and workspace name, a cross-account assume-role name, internal repo paths, and a description of which files hold
credential material and IAM role definitions.

**Nothing leaked.** Verified 2026-10-12: `git log --all --oneline -S'<prod-account-id>' -- claude/settings.json`
returned zero commits, and the committed copy contained no `autoMode` key. The content was staged for a push that had
not happened. Re-run that command with the account ID from the live settings file to re-confirm.

The repo's own `CLAUDE.md` had already predicted this, in the note on why `~/.ssh/config` is deliberately untracked:
*"symlinking it into the repo would dirty the checkout on every such write — the same problem `claude/settings.json`
already has."*

## Goals

- No Indeed-specific content in this repository, by construction rather than by vigilance.
- A fresh machine comes up correctly configured from `./install`.
- Coexist with `setup-ai4dp`, which also writes `~/.claude/settings.json`, without either tool fighting the other.
- Never revert a setting the user changed through the Claude Code UI.
- Removing a rule from a fragment actually removes it from the live file.

## Non-goals

- Owning `~/.claude/settings.json` as a whole. Nobody owns it; three writers merge into it.
- Managing the AI4DP hook entries, the `indeed-ai-marketplace` registration, or the plugins AI4DP installs.
- Changing any current behaviour of the settings themselves. This is a relocation, not a retune.

## Constraints that drive the design

These are the findings the design has to survive, not preferences.

**`setup-ai4dp` is an unattended co-writer.** `session-logging-hooks/hooks/events/session-start.sh` calls
`check_and_apply_update` on every SessionStart, which forks a detached worker, compares the local `VERSION` against the
remote over `git archive --remote`, and runs `setup-ai4dp --hooks-only` when behind. It is gated only by
`AI_HOOKS_AUTO_UPDATE`, which defaults to true. AI4DP's changelog also records that `setup-ai4dp` is registered in
`INDEED_SYSTEM_SETUP_ADDITIONAL_TASKS` as a bare untagged invocation, so it runs on every `system-setup` pass — their
words: "frequently, and invisibly". Check the installed versions with
`cat ~/.claude/{session-logging-hooks,marketplace-instrumentation-hooks}/VERSION`.

**It is well-behaved, and worth imitating.** Per its changelog, `setup-ai4dp` merges with `jq`, is a no-op when the
config is already current, preserves keys it does not own, validates generated output before overwriting, and keeps
trimmed timestamped backups. It is not a clobberer. The conflict is structural, not behavioural.

**An atomic write destroys a symlink.** `setup-ai4dp` writes via temp-file-plus-rename, which is correct safe-write
behaviour and which replaced the dotbot symlink at `~/.claude/settings.json` with a real file. Evidence:
`~/.claude/settings.json.install-logging.backup.<timestamp>`, and the live file carrying the AI4DP hook entries while
the tracked copy carries none. **Any design that re-creates that symlink is defeated within days**, and leaks during
the window before it is.

**A `claude` wrapper cannot carry permission rules.** `--settings <file>` is a real additive layer above user settings,
but a wrapper function only covers invocations that go through the shell function. An IDE extension, the desktop app,
or a tool spawning `claude` would silently drop the layer — including `permissions.ask` entries. A permission rule that
might not load is worse than one known to be absent. Rejected for that reason.

**Project-scoped settings are not a substitute.** Several keys are explicitly second-class there — `autoMemoryDirectory`
is "ignored if set in projectSettings … for security", `footerLinksRegexes` and `spellcheck` are "read from user, flag,
and managed settings only" — and a checked-in project file is the weakest permission tier. It also would not address
the base file's exposure. Unverified and not pursued: whether a `.claude/` directory in a non-repo parent such as
`~/indeed` is discovered at all.

## Layout

```
claude/settings.d/00-base.json             public,  tracked here
indeed/claude/settings.d/50-indeed.json    private, tracked in the submodule
claude/settings_merge.py                   the merge; public, shared by both setup scripts
~/.claude/settings.json                    live; untracked, gitignored, NOT linked
~/.claude/.dotfiles-settings.state.json    what the merge last applied; untracked
```

A `settings.d/` directory rather than fixed filenames, applied in lexical order, so another fragment later — a second
work context, a per-host one — needs no code change. Mirrors `bashrc` globbing `*.func`. A later prefix wins a scalar
conflict.

Each repository applies only its own fragments: `claude/setup.sh` applies `claude/settings.d/*`,
`indeed/claude/setup.sh` applies `indeed/claude/settings.d/*`. The conditional handoff already at the tail of
`claude/setup.sh` is the only coupling, and its existing comment already states the intent: "keeps Indeed-specific
wiring in that repo; this is just a conditional invocation, no Indeed content in the public dotfiles". A machine
without the submodule checked out gets the base alone.

`settings_merge.py` lives in the public repo and is called by both setup scripts. Python rather than `jq` in a shell
heredoc, per this repo's own language guidance: reach for Python "as soon as real data handling appears: JSON or other
structured input", and a heredoc'd `python3 -` is the tell you are past bash — plus heredoc'd Python is unlinted by
`make lint` and effectively untestable. `claude_resume.func` + `claude_resume.py` is the precedent.

## The boundary rule

**A rule goes private when its literal text carries one of these:** an account ID, an IAM or service role name, an
internal repository path, a credential-file path, a deployment target or workspace name, or a statement of which files
hold secrets. Disclosure, not relevance.

**Internal hostnames and internal tool names are explicitly out of scope for this rule.** They are already public in
this repository — verified 2026-10-12, `git grep -lIE 'code\.corp\.indeed\.com' HEAD` returns several committed files
including `.gitmodules`, where the submodule URL makes it unavoidable. Treating them as disclosure would make the rule
one this repo already violates and cannot stop violating, and would make the design undocumentable, since the co-writer
it has to coexist with can only be named. Re-run that `git grep` before arguing the point.

So a rule allowing the AWS CLI stays public: the string carries no account ID. A rule naming an internal tool's
credential header file goes private, because the path is the disclosure. The whole `autoMode.environment` block goes
private, because that is where the account IDs, role names, workspace names, and the map of which files hold credential
material live. Rules that are only *useful* at work but carry none of the listed items stay public, which keeps the base
self-contained and reviewable instead of hollowed out.

Stating the criterion in advance is the point. A per-rule judgement call is what makes this kind of mistake recur.

## Merge semantics

Each fragment declares two blocks, because one mode cannot serve both needs:

```json
{
  "merge": { "permissions": { "allow": ["Bash(some-tool safe:*)"] } },
  "seed":  { "theme": "dark-daltonized" }
}
```

- **`merge`** — the fragment owns it. Fragment wins on conflict, and removal is reconciled against state.
- **`seed`** — applied only when the key is absent from the live file. Without this mode every `./install` would revert
  whatever was last changed in `/config`, and the merge would fight the harness forever.

Per run:

1. Load live settings (or `{}`), state (or `{}`), and the fragments in lexical order.
2. `desired` = union of the fragments' `merge` blocks.
3. `stale` = `state − desired` — entries previously applied and no longer declared.
4. `next` = `live − stale`, then deep-merge `desired` over it, then apply `seed` keys only where absent.
5. Validate `next` is a non-empty JSON object. On failure, warn and write nothing.
6. Write `next` atomically, then write `state = desired`.

Step 5 is copied from AI4DP's documented experience: their changelog records adding exactly this guard after a merge
could produce empty or invalid output and replace the file while reporting success with hooks unwired.

Step 3 is what makes removal safe. Only entries this tool recorded applying are eligible for removal, so a rule added
by hand through `/permissions` is never deleted — the merge cannot distinguish "deleted from the fragment" from "added
out of band" without that record.

### Array identity

Idempotency lives here, so it is specified rather than left to the implementation.

- `permissions.allow` / `deny` / `ask`, and `autoMode.*` — sets of strings, unioned by exact match, order-stable.
- `hooks.<Event>[]` — keyed by the inner `hooks[].command` string. Our entries are recognised by that string; AI4DP's
  and the harness's survive because we never declare them.
- `enabledPlugins` — plain object merge, declaring only the plugins this repo installs.

### Ordering note

`autoMode.soft_deny` must keep `"$defaults"` first, which falls out of base applying before Indeed plus order-stable
union. `autoMode.environment` carries **no** `$defaults` sentinel today, so it replaces the built-in entries rather
than extending them. That is preserved as-is; changing it is a separate decision. Confirm both with
`jq '.autoMode | {soft_deny_first: .soft_deny[0], env_has_defaults: (.environment|index("$defaults"))}'
~/.claude/settings.json`.

## Content split

Described by category. Derive the live inventory with
`jq '{allow: (.permissions.allow|length), env: (.autoMode.environment|length)}' ~/.claude/settings.json` rather than
trusting a count written here.

**Public base** — the generic tool allowances (file tools, common read-only shell commands, build and test runners,
`git`, the AWS CLI, a personal public-GitHub URL); the whole `deny` list, which is generic credential and
destructive-command protection; the generic `ask` entries; this repo's own hooks (update check, notification hooks,
session title, session coordination); the status line; the plugins this repo installs; and `"$defaults"` in
`autoMode.soft_deny`.

**Indeed fragment** — the Atlassian netrc rules; the internal-tool header-file rule; the internal CLI wrapper's
read-only and write verbs, across `allow` and `ask`; the `mcpc` gate, whose rationale text names internal services;
the employer-specific `autoMode.soft_deny` entries; and the entire `autoMode.environment` block.

**Neither — `setup-ai4dp` owns these** — its own hook entries on every event, the plugins it installs and enables, and
the `extraKnownMarketplaces` registration including its `autoUpdate` flag. Declaring any of them in a fragment would
create two writers on one key for no gain, and would resurrect a plugin after a deliberate
`claude plugin disable … --scope user` — the regression AI4DP fixed in DATOOLS-409.

**`seed`** — `theme`, `model`, `editorMode`, `verbose`, `autoCompactEnabled`, `attribution`, and
`permissions.defaultMode`. The last is in `seed` deliberately: it is reachable from `/config`, and a merge-mode rule
would silently revert a deliberate permission-mode change.

## Migration

Containment first. It stands on its own and should land even if the rest slips.

1. `git rm --cached claude/settings.json`, and add it to `.gitignore`.
2. Delete the `~/.claude/settings.json` entry from the `link:` block in `install.conf.yaml`. Leaving it means
   `./install` re-creates a symlink that `setup-ai4dp` will destroy, leaking in the interval.
3. Do **not** commit the working-tree `autoMode` addition to `claude/settings.json`. Its content becomes the Indeed
   fragment; discard the working-tree change once the fragment exists.

Then build the fragments from the live file, wire `settings_merge.py` into both setup scripts, and verify a re-run of
`./install` leaves the live file byte-identical.

## Testing

`claude/test/settings_merge_test.py` under `unittest`, with `claude/test/settings_merge_test.sh` as the entry point so
`run_all_tests.sh` discovers it — the `claude_resume_test.sh` pattern. Each case names a failure it catches:

- fresh install: no live file, fragments and seed applied
- idempotent: a second run is byte-identical
- foreign keys survive: AI4DP hook entries and an unknown key are untouched
- seed is not re-asserted: a live value differing from the fragment is left alone
- removal works: an entry in state and absent from fragments is removed
- removal is scoped: an entry in live that was never in state is **not** removed
- hook identity: re-applying a hook does not duplicate it, and a foreign entry on the same event is untouched
- invalid output refused: a merge yielding a non-object writes nothing and reports failure
- symlink target: the atomic write replaces a symlink with a real file, asserted so the behaviour is documented
- no Indeed fragment: a base-only run succeeds

Plus an end-to-end run of the real `setup.sh` against a throwaway `HOME`, as `claude_resume_test.sh` does.

## Open risks

- **Three writers, one file.** The design keeps their key sets disjoint, but that is a convention, not an enforced
  invariant. If AI4DP starts writing a key a fragment declares, the two will alternate on every run. The
  foreign-keys-survive test detects the symptom, not the cause.
- **State file loss.** Deleting `.dotfiles-settings.state.json` degrades the merge to add-only: nothing breaks, but a
  rule deleted from a fragment before the next run will linger. Acceptable, and worth a comment in the script.
- **The seed set can only grow by hand.** A new harness-written preference will not be seeded until someone adds it, so
  a fresh machine silently starts on the default. There is no list of harness-written keys to derive this from.
