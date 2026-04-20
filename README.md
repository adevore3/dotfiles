# Dotfiles

adevore3's dotfiles managed by [dotbot][dotbot].

Includes:
* Bash shell environment (functions, aliases, configs)
* Vim settings
* Tmux settings
* Git configuration and workflow helpers
* Autojump
* Cheat
* Work specific configs in a private git submodule (`indeed/`)

## Setup

### Cloning

Requires the `gh` CLI:
```bash
gh repo clone adevore3/dotfiles
git submodule update --init --recursive
```

If submodules don't initialize properly:
```bash
git submodule update --init --force --remote
```

### Installation

```bash
./install                # Create symlinks via dotbot
sudo ./env-setup.sh      # Install system dependencies (tmux, vim, jq, etc.)
```

## Development

A `Makefile` provides common commands. Run `make help` to see all targets.

### Testing

Tests use a lightweight framework (`bash/functions/test/test_utils.sh`) with `assert_equals` and `assert_contains` helpers. Test files are named `*_test.sh` and are auto-discovered by the test runner.

```bash
make test                # Run all tests (discovers *_test.sh files recursively)
```

To run a single test file:
```bash
DOTFILES=$(pwd) bash bash/functions/test/search_test.sh
```

Test files exist alongside the code they test:

| Directory | Test File |
|---|---|
| `bash/functions/clipboard/` | `bash/functions/test/clipboard_test.sh` |
| `bash/functions/development/` | `bash/functions/test/development_test.sh` |
| `bash/functions/interactive/` | `bash/functions/test/interactive_test.sh` |
| `bash/functions/io/` | `bash/functions/test/io_test.sh` |
| `bash/functions/navigation/` | `bash/functions/test/navigation_test.sh` |
| `bash/functions/search/` | `bash/functions/test/search_test.sh` |
| `bash/functions/system/` | `bash/functions/test/system_test.sh` |
| `bash/functions/text/` | `bash/functions/test/text_test.sh` |
| `bash/functions/time/` | `bash/functions/test/time_test.sh` |
| `bash/functions/util/` | `bash/functions/test/util_test.sh` |
| `git/functions/` | `git/functions/test/git_functions_test.sh` |
| `tmux/functions/` | `tmux/functions/test/tmux_functions_test.sh` |
| `aws/functions/` | `aws/functions/test/aws_functions_test.sh` |
| `node/functions/` | `node/functions/test/node_functions_test.sh` |
| `ssh/functions/` | `ssh/functions/test/ssh_functions_test.sh` |

### Linting

[Shellcheck][shellcheck] is used for static analysis, configured via `.shellcheckrc`.

```bash
make lint                # Lint functions and scripts
make lint-functions      # Lint only .func files
make lint-scripts        # Lint only .sh files
make lint-verbose        # Verbose output with error codes
```

Install shellcheck if missing:
```bash
sudo apt install shellcheck    # Debian/Ubuntu
```

### Other Useful Targets

```bash
make list-functions      # List all bash functions by category
make stats               # Show repo statistics (function count, line counts, etc.)
make update-submodules   # Update git submodules
```

## Function Help

All functions support `-h` / `--help` to display usage information:

```bash
$ extract --help

NAME:
  extract - Extract any archive file (tar, zip, gz, bz2, etc.)

SYNOPSIS
  extract [OPTIONS] <archive_file>

OPTIONS:
  -h, --help       Prints this message

EXAMPLES:
  extract -h
  extract file.tar.gz
```

## Architecture

The `bash/bashrc` file orchestrates a modular loading system:

1. **Functions** (`*.func`) are sourced first from all subdirectories
2. **Configs** (`config.bash`) are sourced per tool
3. **Aliases** (`aliases.bash`) are sourced per tool

Each tool directory (`git/`, `tmux/`, `vim/`, etc.) independently contributes functions, configs, and aliases.

### Key Directories

| Directory | Purpose |
|---|---|
| `bash/functions/` | Categorized bash functions (clipboard, development, navigation, search, system, text, time, util) |
| `git/functions/` | Git workflow helpers (branch management, cleanup, rebasing, stash) |
| `tmux/functions/` | Tmux automation utilities |
| `aws/functions/` | AWS CLI helpers |
| `node/functions/` | Node.js/nvm utilities |
| `ssh/functions/` | SSH setup helpers |

## Inspiration

This was inspired by anishathalye's [article][managing_your_dotfiles] on how
to manage your own dotfiles using his [dotfiles template][anishathalye_dotfiles_templates]
and [dotbot][dotbot].

## License

This software is hereby released into the public domain. That means you can do
whatever you want with it without restriction. See `LICENSE.md` for details.

That being said, I would appreciate it if you could maintain a link back to
Dotbot (or this repository) to help other people discover Dotbot.

[dotbot]: https://github.com/anishathalye/dotbot
[anishathalye_dotfiles_templates]: https://github.com/anishathalye/dotfiles_template
[managing_your_dotfiles]: http://www.anishathalye.com/2014/08/03/managing-your-dotfiles/
[shellcheck]: https://www.shellcheck.net/

