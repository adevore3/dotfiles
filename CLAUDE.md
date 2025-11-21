# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository using [dotbot](https://github.com/anishathalye/dotbot) for installation management. The repository manages shell configurations (bash, vim, tmux, git), utility scripts, and work-specific configurations (in the `indeed/` submodule).

## Installation & Setup

**Initial setup:**
```bash
./install
```
This runs dotbot to create symlinks and execute the env-setup.sh script.

**Environment setup (installs dependencies):**
```bash
sudo ./env-setup.sh
```
Installs system packages (tmux, vim, jq, etc.), autojump, cheat, and tmux plugins.

**Cloning with submodules:**
```bash
gh repo clone adevore3/dotfiles
git submodule update --init --recursive
```

If submodules fail to initialize:
```bash
git submodule update --init --force --remote
```

## Testing

**Run all tests:**
```bash
./run_all_tests.sh
```
Discovers and executes all `*_test.sh` files in the repository. Test files use utilities from `bash/functions/test/test_utils.sh` (assert_equals, assert_contains).

**Run individual test:**
```bash
bash bash/functions/test/log_utils_test.sh
```

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

## Notes

- The `~/.localrc` file contains per-host configurations (sourced from bashrc)
- SSH agent configuration in bashrc maintains persistent SSH connections
- Custom `command_not_found_handle` uses figlet/fortune/cowsay for fun error messages
- Autojump integration for fast directory navigation
- Vi mode enabled for command line editing
