# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository using [dotbot](https://github.com/anishathalye/dotbot) for installation management. The repository manages shell configurations (bash, vim, tmux, git), utility scripts, and work-specific configurations (in the `indeed/` submodule).

## Installation & Setup

Supports Debian/Ubuntu and macOS. Everything platform-specific branches on `uname -s`.

**Initial setup:**
```bash
./install
```
This runs dotbot to create symlinks and execute the env-setup.sh script.

**Environment setup (installs dependencies):**
```bash
./env-setup.sh
```
Installs system packages (tmux, vim, jq, etc.), autojump, cheat, and tmux plugins. Uses `apt` on Linux and
Homebrew on macOS.

Run it **unprivileged** — it elevates per-command with `sudo` where needed, because Homebrew refuses to run as
root. Two things break if the whole script runs under `sudo`: Homebrew aborts outright, and on Linux `sudo`'s
`env_reset` drops `HOME`, so autojump and the tmux plugins install into `/root` where nothing reads them.

**Cloning with submodules:**
```bash
gh repo clone adevore3/dotfiles
git submodule update --init --recursive
```

If submodules fail to initialize:
```bash
git submodule update --init --force --remote
```

`./install` only initializes the `dotbot` submodule, so run the command above too — otherwise every vim bundle,
tpm and `indeed/` stay empty directories, and `claude/setup.sh` silently skips the `indeed/` handoff.

### macOS specifics

**The login shell is `zsh` by default, but these dotfiles configure `bash`.** Nothing loads until you point the
shell at Homebrew's bash — `/bin/bash` is 3.2 (2007) and too old for some constructs:

```bash
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
```

Homebrew must already be installed; `env-setup.sh` refuses to continue without it.

### Portability

**Use `bash/functions/platform_utils.sh` rather than branching at the call site.** The GNU-vs-BSD flag
differences that keep breaking this repo are wrapped there once, feature-probed on `--version` (only the GNU
builds answer) so a mac with Homebrew coreutils ahead of `/usr/bin` takes the GNU path:

| Instead of | Use | Why |
| --- | --- | --- |
| `date -d @N` / `date -ud @N` | `date_from_epoch [-u] <epoch> [fmt]` | BSD spells it `-r N` and has no `-d` |
| `date -d <str> +%s` | `epoch_from_datetime <str>` | BSD needs `-j -f <fmt>` with the format known up front |
| `date -d "<t> + 1 month"` | `date_shift <t> '+1 month' [fmt]` | BSD spells it `-v+1m`; never hand GNU a *signed* count |
| `date +%:z` | `utc_offset_colon [epoch]` | BSD has no `%:z` — it prints a literal `:z` and exits 0 |
| `stat -c %Y` | `file_mtime_epoch <file>` | BSD spells it `-f %m`; `-c` is an illegal option |
| `sed -i` / `sed -i -r` | `sed_in_place <expr> <file>...` | BSD `-i` needs an argument and rejects `-r` (use `-E`) |
| `xdg-open` | `open_target <path-or-url>` | macOS has no `xdg-open`; Linux's `open` opens a virtual console |
| `xclip -sel clip` | `clipboard_write` (or `save_to_clipboard`) | macOS has `pbcopy`; Wayland wants `wl-copy` |

`bash/functions/test/platform_utils_test.sh` asserts identical behavior on whichever `date`/`sed`/`stat` the
host ships, so the same suite is the portability check on both platforms.

`_system_clipboard_command` (in `save_to_clipboard.func`) resolves `pbcopy` → `wl-copy` → `xclip`, gating
`wl-copy` on `WAYLAND_DISPLAY` because it is often installed on X11 boxes where it cannot reach a compositor.
It returns a command **string**, so callers must expand it *unquoted* — `"xclip -selection c"` has to
word-split into a program plus two arguments. Only one of the three tools exists on any host, so
`clipboard_test.sh` exercises the other branches against stub executables on a synthetic `PATH`; that is the
only way to assert the Linux ordering from a mac.

**Portability rules when touching shell code here.** Each of these has already broken this repo on macOS:

- **No `mapfile`/`readarray`** — bash 4+, absent from macOS's `/bin/bash` 3.2. Use a read loop, and include
  `|| [ -n "$line" ]` so a final line with no trailing newline is not dropped (`mapfile` kept it).
- **No `/proc`** — no `/proc/loadavg`; use `sysctl -n vm.loadavg`.
- **No systemd** — no `hostnamectl`; fall back to `hostname -s`. Guard it, since an unguarded miss trips
  `command_not_found_handle` and prints the figlet/cowsay banner, and `prompt.bash` runs on every render.
- **No process-owning `netstat`** — BSD netstat has no `-t`/`-u`/`-p` and cannot attribute a socket to a
  process; `lsof -iTCP -sTCP:LISTEN` is the equivalent. See `list_listening_ports.func`.
- **`wc -l` right-pads its count** on BSD (`"       1"`). Strip whitespace before comparing.
- **`ps -o ucomm=` right-pads too**, to `"ssh-agent       "` on Darwin, so an equality test against it is false
  forever and any guard built on it silently never fires. `ps -o comm=` prints the bare name on both platforms —
  that is the one to use, and bashrc's agent-reuse guard depends on it.
- **`#!/usr/bin/env bash`, never `#!/bin/env bash`** — `/bin/env` only exists where `/bin` is merged into
  `/usr/bin`.
- **Guard optional tools at startup** (`type foo &> /dev/null && ...`). An unguarded `kubectl`/`hostnamectl`
  means an error on every new shell.
- **Never hardcode `/home/$USER`** — see the note on Claude project slugs below.
- **Don't assume a Linux desktop layout** — screenshots land on `~/Desktop` on macOS, not
  `~/Pictures/Screenshots`; `xrandr`, `bluetoothctl` and `diodon` have no macOS counterpart at all.
- **`date_shift`'s GNU branch must never be given a signed count.** Directly after a time, GNU reads `+1` as a
  *timezone offset*, so `date -d "<t> +1 month"` means "<t> at +01:00, then plus a month", and `- 1 month`
  becomes -01:00 and then *adds* a month — the wrong direction, silently. The wrapper passes an unsigned count
  and GNU's own `ago` keyword instead. A base that already carries an offset happens to be immune, which is why
  `modify_partition` never tripped over it.
- **BSD `date -j -f` accepts a *partial* match, so never trust its exit status alone.** Given a format that
  consumes only a prefix it prints `Warning: Ignoring N extraneous characters`, emits an epoch for the prefix,
  and still exits 0. That silently dropped the trailing offset from `2026-01-01T00:00:00-06:00` and returned a
  *local-zone* epoch where GNU returned the right instant, and it accepted `...T00:00:00GARBAGE` just as
  happily. `epoch_from_datetime` now folds stderr into stdout and requires the result to be bare digits — a
  clean full parse prints nothing else. Any new `-j -f` call site needs the same guard.
- **A failed `date` must never be allowed to reach a `sed -i`.** `modify_partition` is now portable —
  `date_shift` for the arithmetic, `utc_offset_colon` for `%:z`, `sed_in_place` for the edit — but porting it
  exposed a live data-loss bug that had nothing to do with platform. With no partition flag `$selected_partition`
  was empty, so `date -d "<date> + 1 "` failed, `$new_date` came out empty, and GNU sed wrote that empty string
  over the real date: running `modify_partition` with no flag *deleted both dates in `run.sh`*. The old note here
  claimed BSD sed rejecting `-i` was the only thing preventing that, which was true on BSD and false on the
  platform the function actually ran on. It now refuses without a flag, checks `date_shift`'s exit status, and
  pattern-matches `$new_date` before writing. `modify_partition_test.sh` drives all of it against a throwaway
  `run.sh`; its expected values are literals taken from the pre-port GNU implementation, verified equal across a
  96-case matrix, so the same assertions hold on BSD.
- **An SSH agent existing is not the same as an SSH agent working.** macOS always exports a launchd agent in
  `SSH_AUTH_SOCK` and it is usually *empty*, so bashrc's `-S` test repointed the shared `~/.ssh/ssh_auth_sock`
  link at a useless agent, and the local-agent fallback — gated on the socket merely existing — skipped itself.
  Result: no key, every push failing `Permission denied (publickey)`, and nothing visibly wrong. Both now gate
  on `_ssh_agent_has_keys` (`ssh-add -l`: 0 keys, 1 reachable-but-empty, 2 unreachable), and the adopt step
  refuses to replace a keyed link with an empty agent — otherwise opening one terminal breaks ssh in every
  running tmux pane, since they all read that one link. `bash/functions/test/ssh_agent_link_test.sh` drives the
  real block out of `bashrc` against live agents. Two further guards, both added after watching it misbehave:
  the fallback binds its agent to a **fixed** socket (`~/.ssh/ssh_agent_own_sock`) so repeated shells share one
  instead of orphaning a fresh agent apiece — four leaked in a single nested-shell test — and it only runs
  `ssh-add` when `[ -t 0 ]`, since an interactive-but-ttyless shell otherwise printed a passphrase prompt
  nothing could answer and leaked an agent doing it. Note the probe is wrapped in `timeout` *where available*: a
  stale agent socket can accept a connection and never answer, and macOS has no `timeout` of its own (Homebrew
  coreutils ships it as `gtimeout`), so it must degrade to a bare call rather than assume it.
- **A forwarded agent is not a persistent one, and preferring it is what made the cloudvm's agent look like it kept
  "expiring".** `ssh -A` gets you a socket sshd creates at `/tmp/ssh-*/agent.<pid>` and **unlinks when the connection
  ends** — the laptop's agent is still running with its keys, but `~/.ssh/ssh_auth_sock` dangles and ssh dies in every
  tmux pane at once. Two things conspired: the BOXY block gives `*.cvm.indeed.net` `ServerAliveInterval 60` with the
  default `CountMax 3`, so ~3 minutes of a closed lid tears the connection down (now overridden to 30×25 from
  `indeed/ssh/config.d/30-indeed.conf`, which wins because the config.d `Include` is prepended above the
  DO-NOT-EDIT block and ssh keeps the first value); and the local-agent fallback never fired there, because the adopt
  step repointed the link at the fresh forwarded socket first and the gate only asked whether the link held *keys*.
  `~/.ssh/ssh_agent_own_sock` had never once been created on that host. So the gate is now
  `_ssh_agent_needs_own`, which also fires when a keyed link is backed by a socket belonging to this connection —
  keyed on `SSH_CONNECTION` rather than a per-host flag, since any flag would have to be set above the adopt rule and
  the per-host `config.bash` files are sourced well below it. A keyed agent of ours then wins the adopt outright, and
  the forwarded socket stays reachable as `SSH_AUTH_SOCK_FORWARDED` for hosts that trust the laptop's keys and not
  this machine's. Cost is one passphrase per agent lifetime instead of per login. **That last part is not
  hypothetical: github.com knows a laptop key and not the cloudvm's, so `git push` on the dotfiles remote started
  failing `Permission denied (publickey)` the moment the local agent took the link** — while code.corp, which does
  know the cloudvm's key, kept working. Two lessons paid for there. Preferring a local agent silently changes *which
  identity* every remote sees, so any remote that only knew the forwarded keys has to be re-registered (or pointed at
  `SSH_AUTH_SOCK_FORWARDED`); check with `ssh -T` per host rather than assuming. As of 2026-08-18 the cloudvm's
  `~/.ssh/id_ed25519` is registered on **neither** host — `glab api --hostname code.corp.indeed.com user/keys` lists
  only two laptop keys plus an expired "Sourcegraph Campaign", and `curl -sS https://github.com/adevore3.keys` serves
  two keys that are not it — so the persistent agent currently authenticates nowhere and git rides the forwarded agent
  via the `Match host ... exec` blocks in `ssh/config.d/00-common.conf` and `indeed/ssh/config.d/30-indeed.conf`. Those
  two endpoints are the authority on what a host will accept; a comment claiming otherwise has already been wrong once. And the capture of the forwarded path
  has to sit *above* both relink branches — it was originally inside the adopt branch, which does not run on the login
  that first starts our own agent, so the escape hatch was unset in precisely the session that needed it. Verified by driving both the old and
  new logic out of `bashrc` under `script -qec` through login → disconnect → reconnect: the old one goes `keys=NO` at
  the disconnect, the new one stays keyed. That harness is deliberately *not* committed — `script`'s syntax differs on
  BSD, the same reason `ssh_agent_link_test.sh` leaves the `[ -t 0 ]` branch to real terminal use — so the committed
  tests assert the decisions (adopt, gate, relink) against live agents instead.
- **tmux copy goes through `$copy_command`** in `tmux.conf`, not a hardcoded `pbcopy`. tmux-yank overrides
  those `bind-key` lines once tpm loads, so the binds are only the fallback for the plugin not loading —
  `@override_copy_command` is what actually decides the tool. Two traps, both verified by driving a real yank
  and watching which binary gets exec'd (`list-keys` alone will mislead you):
  - **Set `@override_copy_command` before the `run '.../tpm'` line.** yank reads it while building its binds;
    setting it lower in the file is silently too late.
  - **Keep `$VAR` out of `$copy_command`.** tmux escapes the `$` when interpolating into the option, so the
    copy-pipe shell sees a literal `$WAYLAND_DISPLAY` — non-empty, making any such test read true. This is why
    the tmux string resolves pbcopy → xclip only, while `_system_clipboard_command` can gate on Wayland.

  Without the override, yank's own detection prefers `wl-copy` on nothing more than the binary existing, so
  installing `wl-clipboard` (which `env-setup.sh` now does) breaks copy on any X11 Linux box.

## Development Commands

This repository includes a Makefile for common operations. Run `make help` to see all available targets.

**Common commands:**
```bash
make help               # Show all available commands
make test               # Run all tests
make lint               # Run shellcheck on all shell files
make stats              # Show repository statistics
make list-functions     # List all bash functions by category
make install            # Install dotfiles (creates symlinks)
make update-submodules  # Update git submodules
```

### Testing

**Run all tests:**
```bash
make test
# or directly:
./run_all_tests.sh
```
Discovers and executes all `*_test.sh` files in the repository. Test files use utilities from `bash/functions/test/test_utils.sh` (assert_equals, assert_contains).

**Run individual test:**
```bash
bash bash/functions/test/log_utils_test.sh
```

### Linting

The repository uses [shellcheck](https://www.shellcheck.net/) for shell script linting, configured via `.shellcheckrc`.

**Lint all code:**
```bash
make lint               # Lint both functions and scripts
make lint-functions     # Lint only bash functions
make lint-scripts       # Lint only shell scripts
make lint-verbose       # Verbose output with error codes
```

**Configuration:**
- `.shellcheckrc` - Disables SC1090/SC1091 (can't follow non-constant source paths)
- Excludes third-party code (autojump, dotbot, indeed submodules)

## Architecture

### Configuration Loading System

The `bash/bashrc` file orchestrates a modular loading system:

1. **Functions** - All `*.func` files are sourced first (from any subdirectory)
2. **Configs** - All `config.bash` files are sourced (per-tool configurations)
3. **Aliases** - All `aliases.bash` files are sourced (per-tool command shortcuts)

This pattern allows each tool directory (git/, tmux/, vim/, etc.) to independently contribute functions, configs, and aliases.

### Directory Structure

- **bash/** - Core shell environment
  - `bashrc` - Main entry point, loads all configurations
  - `config.bash` - Shell behavior (history, vi mode, completion)
  - `functions/` - Categorized bash functions (42 total):
    - `clipboard/` - Clipboard operations (save_to_clipboard, save_to_tmux_clipboard, save_to_all_clipboards)
    - `development/` - Development workflow utilities (source_dotfiles_file, awkp, open_scratch, etc.)
    - `git/` - Git workflow helpers (git_smart_commit_message)
    - `interactive/` - User interaction utilities (select_from_options, alias_grep_execute)
    - `io/` - Input/output capture utilities (cap, ret)
    - `navigation/` - Directory navigation (mkcd, up, tre)
    - `search/` - Search and grep utilities (eg, egv, find_grep, lsgrep, all_commands_grep)
    - `system/` - System utilities (myip, extract, bluetooth_connect, modify_partition)
    - `text/` - Text processing (trim, urlencode, highlight, join_by)
    - `time/` - Time and date utilities (unixtime, from_unixtime, date_diff, from_datetime)
    - `util/` - Miscellaneous utilities (calculate, check_variable, conditionally_prefix_path, etc.)
  - `functions/test/*_test.sh` - Unit tests for bash functions
  - `functions/log_utils.sh` - Logging framework (DEBUG/INFO/WARN/ERROR levels)
  - `functions/bash_utils.sh` - Command existence checks

- **git/** - Git configurations and utilities
  - `gitconfig` - Git settings
  - `functions/*.func` - Git workflow helpers (branch management, cleanup, rebasing)

- **tmux/** - Tmux configurations
  - `tmux.conf` - Tmux settings
  - `functions/*.func` - Tmux automation utilities

- **vim/** - Vim configuration
  - `vimrc` - Vim settings

- **workspace/** - General workspace utilities
  - `docker/` - Docker cleanup scripts
  - `java/` - Java-related utilities
  - `caleb/` - Personal scripts

- **indeed/** - Work-specific configurations (private git submodule)
  - Follows same structure as main repo (bash/, git/, aws/, workspace/, etc.)
  - Contains company-specific aliases, functions, and scripts

- **misc/** - Miscellaneous utilities
  - `scripts/` - Code analysis tools (cloc, line counting)

- **claude/** - Claude Code configuration
  - `CLAUDE.md`, `settings.json`, `statusline-command.sh` - global config, symlinked by dotbot
  - `hooks/` - session-name, notification and session-coordination hooks
  - `skills/`, `memory/` - skills and per-project memory, symlinked into `~/.claude/`
  - `setup.sh` - links whatever dotbot cannot, because the target path is computed (see below)

### Per-host and per-platform config

**`bash/setup.sh` links the config whose *source* path is computed**, which dotbot's `link:` cannot express.
Same division of labor as `claude/setup.sh`, and dotbot invokes it the same way. Two jobs:

- `~/.localrc` → `bash/localrc_<hostname -s>`, falling back to `bash/localrc_<uname -s>`. Hostname first
  because two hosts can share an OS and still want different content — the cloudvm and a Linux laptop are both
  `Linux`. `~/.localrc` is sourced by `bashrc` *before* the `*.func` files, so helpers like
  `conditionally_prefix_path` are not defined yet; guards there have to be written inline.
- `~/.ssh/config.d/00-common.conf` always, plus `10-<uname -s>.conf` when one exists, and it **prunes
  fragments belonging to other platforms**. A pruned fragment that is a link into the repo is deleted; anything
  else is renamed to `.pre-dotfiles`, which is outside the `*.conf` glob and so defuses it just as well without
  discarding content the script did not create.

**Secrets go in `~/.localrc.secrets`, never in a tracked `localrc_*`.** `bashrc` sources it immediately after
`~/.localrc`, so a secret overrides any tracked default, and git never sees it. This exists because `~/.localrc`
is now a *symlink into the repo*: a real file holding credentials there would be displaced to
`~/.localrc.pre-dotfiles` by `bash/setup.sh` and the tracked file linked over it — no error, but every new shell
silently loses the exports, and the obvious "fix" is to paste secrets into git.

**The cloudvm is migrated.** `GLAB_TOKEN`, `SLACK_WEBHOOK_URL` and `NTFY_TOPIC` moved to `~/.localrc.secrets`
(mode 600); `~/.localrc` keeps only the non-secret `DEVOPSCLOUD_ROOT`. All four are live in a fresh login shell.
The macbook has no secrets in `~/.localrc` — all three are unset there — so the hazard is dormant on that host
rather than absent.

What is left there is now benign: `~/.localrc` is still a *real file*, so adding a candidate filename would
displace it to `~/.localrc.pre-dotfiles` and cost `DEVOPSCLOUD_ROOT` rather than a credential. Whoever adds one
should carry that export into it.

Note hostname keying does not help the cloudvm: `hostname -s` is `ip-10-217-86-67`, derived from the private IP,
so it changes if the instance is replaced. That leaves `localrc_Linux`, shared with the Linux laptop — the thing
hostname-first was meant to avoid.

**A per-platform ssh fragment is not a nicety — an unrecognized option is fatal.** `UseKeychain` is an Apple
extension, and Linux OpenSSH answers it with `Bad configuration option: usekeychain` and
`terminating, 1 bad configuration options`, which takes ssh down entirely rather than ignoring one line. So it
cannot live in a shared file. Three behaviors make the split work, all verified:

- A missing `Include` path — literal or glob, missing file or missing directory — is silently ignored, so the
  same config ships to a host where the fragment is absent.
- ssh takes the **first** value it obtains for an option, so the `Include` must *precede* any conflicting
  `Host` block. `bash/setup.sh` prepends it for that reason.
- `~/.ssh/config` itself is deliberately **not** tracked. OrbStack and installers like it append to that file,
  and symlinking it into the repo would dirty the checkout on every such write — the same problem
  `claude/settings.json` already has. Only the fragments are tracked.

### Claude config & memory linking

Fixed-path files (`~/.claude/settings.json`, hooks, skills) are plain dotbot `link:` entries in
`install.conf.yaml`. Anything whose *target path has to be computed* lives in `claude/setup.sh` instead, which
dotbot invokes as a shell command. `indeed/claude/setup.sh` is the same idea for work-specific wiring, and the
public script hands off to it when the submodule is checked out.

**Per-project memory is keyed by the repo's absolute checkout path**, with `/` turned into `-`:
`/home/adevore/dotfiles` becomes `~/.claude/projects/-home-adevore-dotfiles/memory`. So **derive the slug from
`$HOME` (or the repo path), never from `/home/$USER`** — a hardcoded `/home` builds slugs Claude never looks up
on macOS, and the memory silently fails to load rather than erroring. Strip a trailing slash before
slugifying, or `$HOME=/home/adevore/` yields a double dash:

```bash
HOME_SLUG="${HOME%/}"
HOME_SLUG="${HOME_SLUG//\//-}"
```

Both setup scripts are idempotent and safe to re-run; each verifies its symlinks resolve and exits non-zero if
one dangles. dotbot's `clean:` only sweeps `~` and `~/.config`, so each script prunes its own orphaned skill
links — a renamed skill otherwise leaves a dangling link that Claude still tries to load.

### Key Utilities

**Logging System** (`bash/functions/log_utils.sh`):
- Log levels: DEBUG=1, INFO=2, WARN=3, ERROR=4
- Functions: `log_debug`, `log_info`, `log_warn`, `log_error`
- Configure with `set_log_level` or `LOG_LEVEL` environment variable
- Used throughout scripts for consistent logging

**Test Framework** (`bash/functions/test/test_utils.sh`):
- `assert_equals` - Compare two values
- `assert_contains` - Check substring presence
- Tests exit with code 1 on failure

**Function Sourcing**:
- Functions are sourced via `source "${DOTFILES}/path/to/file.sh"`
- Most functions export themselves for subprocess availability
- `DOTFILES` environment variable points to repo root

### Important Patterns

**Function Dependencies**:
Many `*.func` files source their dependencies at the top:
```bash
source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/bash_utils.sh"
```

**Command Existence Checks**:
Use `bash_utils.sh`:
```bash
check_command_exists git "Please install git"
```

**Error Handling**:
Scripts use `set -uo pipefail` for strict error handling.

### Choosing bash, Python, or both for a new function

Decide this before writing the function, not after it grows. Getting it wrong is what produces long
`*.func` files with a Python heredoc bolted into the middle.

**Bash** — the default for glue: a handful of commands, env/PATH/alias work, wrapping a CLI, and anything that must
change the calling shell (`cd`, `export`, defining functions). Only a shell function can move your shell; a child
process cannot.

**Python** — reach for it as soon as real data handling appears: JSON or other structured input, sorting and
aggregating records, column layout, string-width math, or a pile of regexes. Signals you are past bash: a heredoc'd
`python3 - <<'PY'`, `read`/`awk`/`sed` parsing a structured format, or arithmetic to keep output aligned.

**Hybrid** — a thin `*.func` wrapper over a `*.py` module, when the work needs both real data handling *and* shell
side effects. `claude_resume.func` + `claude_resume.py` is the reference: the wrapper stays ~70 lines (mostly its
usage block) and does nothing but run the script, read the result, `cd`, and exec. Conventions that make it work:

- Hand results back through a temp file (`--result-file`), not stdout, so the script keeps the real terminal — colors,
  tables and prompts then behave exactly as if it ran directly.
- Pass `COLUMNS` explicitly. Bash keeps it current but does not export it, so a child sees nothing.
- Mirror `log_utils.sh` output in the Python (`[INFO]` to stdout, `[ERROR]` to stderr, honoring `LOG_LEVEL`) so
  messages from both halves are indistinguishable.

**Two bash traps worth knowing** (both hit `claude_resume` before it was ported):

- `IFS=$'\t' read` collapses empty fields, because tab is IFS *whitespace*. Never move tabular data across a
  language boundary as TSV — one empty cell silently shifts every later column.
- `printf '%-*s'` pads by *bytes* while `${#var}` counts *characters*. Any output mixing ANSI escapes or non-ASCII
  with column alignment needs hand-tracked byte accounting in bash, and none at all in Python.

**Testing follows the language.** `make lint` (shellcheck) covers `*.func`/`*.sh` but cannot see inside a quoted
heredoc, so heredoc'd Python is unlinted and effectively untestable. A real `.py` gets `unittest` coverage; give it a
thin `*_test.sh` entry point, since `run_all_tests.sh` only discovers `*_test.sh`. See
`claude/test/claude_resume_test.sh`, which delegates to `claude_resume_test.py` and then drives the wrapper
end-to-end against a throwaway `HOME` with a fake binary on `PATH`.

## Notes

- The `~/.localrc` file contains per-host configurations (sourced from bashrc)
- SSH agent configuration in bashrc maintains persistent SSH connections
- Custom `command_not_found_handle` uses figlet/fortune/cowsay for fun error messages
- Autojump integration for fast directory navigation
- Vi mode enabled for command line editing
