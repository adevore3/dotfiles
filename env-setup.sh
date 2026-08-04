#!/usr/bin/env bash

# Resolve repo root from this script's own location: sudo strips DOTFILES from the environment,
# so relying on the env var leaves the source path empty and log_* helpers undefined.
# Must be EXPORTED, not just set: tmux.conf does `run '$DOTFILES/tmux/plugins/tpm/tpm'`, which the tmux
# server expands from its own environment. Unexported, tpm never loads and install_tmux_plugins below
# silently installs nothing.
export DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "${DOTFILES}/bash/functions/log_utils.sh"

# Platform dispatch. The same tool set installs through apt on Debian and Homebrew on macOS, but package
# names differ and a few tools are Linux-only, so the lists below branch on this.
# Run this script UNPRIVILEGED: it elevates per-command with sudo where needed, because Homebrew refuses
# to run as root.
OS="$(uname -s)"

# -y because dotbot runs this script with stdin closed, so apt's confirmation prompt would abort the install
# with nothing able to answer it. Scoped to this script on purpose — the old /etc/apt/apt.conf.d/90assumeyes
# drop-in did the same thing to every apt invocation on the machine.
function apt_install() { sudo apt install -y "$1"; }
function brew_install() { brew install "$1"; }

case "$OS" in
  Linux)
    PKG_INSTALL=apt_install
    ;;
  Darwin)
    PKG_INSTALL=brew_install
    if ! hash brew 2>/dev/null; then
      log_error "Homebrew not found. Install it first: https://brew.sh"
      exit 1
    fi
    ;;
  *)
    log_error "Unsupported platform '$OS'; expected Linux or Darwin."
    exit 1
    ;;
esac

# Collects the names of anything that failed, so a broken install is reported at the end and the script
# exits non-zero instead of dotbot calling the whole run a success.
FAILURES=""

function installing_template() {
  local program_name=$1;
  shift
  local installation_function=$1;
  shift

  log_info "Checking for the existence of '$program_name'"
  if hash "$program_name" 2>/dev/null; then
    log_info "  '$program_name' already installed, skipping"
  else
    log_info "  Installing '$program_name'..."
    # Check the exit status: this used to claim success unconditionally, hiding real failures
    # (autojump's installer aborting, a package name that does not exist on this platform).
    if "$installation_function" "$@"; then
      log_info "  Successfully installed '$program_name'"
    else
      log_error "  FAILED to install '$program_name'"
      FAILURES="$FAILURES $program_name"
    fi
  fi
}

# pkg_install_template <binary> [package]
# `hash` tests for the *binary*, which is not always the package name (ag/silversearcher-ag,
# http/httpie), so take both and default package to binary when they match.
function pkg_install_template() {
  local binary="$1"
  local package="${2:-$1}"
  installing_template "$binary" "$PKG_INSTALL" "$package"
}

function install_cheat() {
  # Upstream ships per-OS release binaries and Homebrew has a formula, so only Linux needs the manual fetch.
  if [ "$OS" = Darwin ]; then
    brew install cheat
  else
    log_info "  Installing cheat version 4.4.0. For latest version check out https://github.com/cheat/cheat/blob/master/INSTALLING.md"

    cd /tmp \
      && wget https://github.com/cheat/cheat/releases/download/4.4.0/cheat-linux-amd64.gz \
      && gunzip cheat-linux-amd64.gz \
      && chmod +x cheat-linux-amd64 \
      && sudo mv cheat-linux-amd64 /usr/local/bin/cheat
  fi

  # Cheatsheets are found via this repo's conf.yml on both platforms. community/ is a submodule now, so
  # only clone when it was never checked out — otherwise git refuses on the non-empty directory.
  if [ ! -e "$DOTFILES/cheat/cheatsheets/community/.git" ]; then
    cd "$DOTFILES/cheat/cheatsheets/" || return 1
    git clone https://github.com/cheat/cheatsheets community
  fi
}

# install.py copies its scripts verbatim, so they keep autojump's own `#!/usr/bin/env python` shebang and
# `j` then dies with "env: python: No such file or directory" anywhere only python3 exists — modern macOS
# and Debian both. Repoint them. Written through a temp file and `cat` back so the executable bit survives,
# and because `sed -i` takes an argument on BSD but none on GNU.
# Idempotent, and called outside install_autojump as well: installing_template skips the install entirely
# once `autojump` is on PATH, so a host set up before this fix existed would otherwise keep the broken
# shebangs forever — including a Linux box that only works today because /usr/bin/python still exists.
function repoint_autojump_shebangs() {
  local f tmp
  for f in "$HOME/.autojump/bin/autojump" "$HOME"/.autojump/bin/*.py; do
    [ -f "$f" ] || continue
    grep -q '^#!/usr/bin/env python$' "$f" || continue
    log_info "  Repointing $(basename "$f") shebang at python3"
    tmp="$(mktemp)" || return 1
    if sed '1s|^#!/usr/bin/env python$|#!/usr/bin/env python3|' "$f" > "$tmp"; then
      cat "$tmp" > "$f"
    fi
    rm -f "$tmp"
  done
}

function install_autojump() {
  # Use the vendored installer, not a package manager: bash/config.bash sources
  # $HOME/.autojump/etc/profile.d/autojump.sh, which is where install.py puts it.
  # Invoke through python3 explicitly — install.py's shebang asks for `python`, which macOS does not ship.
  cd "$DOTFILES/autojump/autojump" || return 1
  python3 ./install.py || return 1

  repoint_autojump_shebangs || return 1

  # The installer leaves `j` defined from the previous shell, so verify the binary itself actually runs.
  "$HOME/.autojump/bin/autojump" --version >/dev/null 2>&1
}

function install_tmux_plugins() {
  # Start a session to install plugins
  tmux new -d -s test || return 1
  "$DOTFILES/tmux/plugins/tpm/bindings/install_plugins"

  # tpm reports success even when it installed nothing (e.g. $DOTFILES missing from the tmux server's
  # environment leaves tpm itself unloaded), so confirm the plugins actually landed. tpm clones into
  # TMUX_PLUGIN_MANAGER_PATH, which it defaults to ~/.tmux/plugins — NOT this repo's tmux/plugins/,
  # which only holds the vendored tpm submodule. Read the path back from the live server.
  local plugin_path
  plugin_path="$(tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>/dev/null | cut -d= -f2-)"
  plugin_path="${plugin_path:-$HOME/.tmux/plugins}"
  tmux kill-session -t test

  # Derive the expected set from tmux.conf's @plugin lines so this check cannot drift from the config.
  # Process substitution, not a pipe: the loop must run in this shell so $missing survives it.
  local missing="" plugin
  while IFS= read -r plugin; do
    [ -d "${plugin_path%/}/$plugin" ] || missing="$missing $plugin"
  done < <(sed -n "s|^set -g @plugin '[^/]*/\([^']*\)'.*|\1|p" "$DOTFILES/tmux/tmux.conf")
  if [ -n "$missing" ]; then
    log_error "tmux plugins did not install into ${plugin_path%/}:$missing"
    return 1
  fi
}

log_info "Installing various commands"
pkg_install_template "cowsay"
pkg_install_template "figlet"
pkg_install_template "fortune"
pkg_install_template "htop"
pkg_install_template "http" "httpie"
pkg_install_template "jq"
pkg_install_template "pv" # monitor the progress of data through a pipe
pkg_install_template "rename"
pkg_install_template "shellcheck"
pkg_install_template "tmux"
pkg_install_template "tree"
pkg_install_template "vim"
pkg_install_template "wget"

case "$OS" in
  Linux)
    pkg_install_template "ag" "silversearcher-ag"
    pkg_install_template "diodon"           # GTK clipboard manager (the GUI, not a CLI -- see xclip below)
    pkg_install_template "netstat" "net-tools"
    pkg_install_template "preload"          # will move binaries/dependencies of your most-used apps in to the memory by predicting as per your usage
    # The clipboard CLIs _system_clipboard_command resolves against. Nothing installed these before, so
    # save_to_clipboard warned "install xclip" on every fresh Linux box and was right to. xclip covers X11 and
    # XWayland; wl-clipboard provides wl-copy, preferred inside a real Wayland session. macOS needs neither,
    # since pbcopy ships with the OS.
    pkg_install_template "xclip"
    pkg_install_template "wl-copy" "wl-clipboard"
    ;;
  Darwin)
    pkg_install_template "ag" "the_silver_searcher"
    # netstat/ifconfig and pbcopy ship with macOS; diodon, preload and the X11/Wayland clipboard CLIs have no
    # macOS equivalent.
    ;;
esac

installing_template "autojump" install_autojump
# Unconditional: the line above is a no-op once autojump is on PATH, but an install predating the shebang fix
# still has `#!/usr/bin/env python` scripts that break as soon as a host stops shipping /usr/bin/python.
repoint_autojump_shebangs || FAILURES="$FAILURES autojump-shebangs"
installing_template "cheat" install_cheat

log_info "Installing tmux plugins"
install_tmux_plugins || FAILURES="$FAILURES tmux-plugins"

log_info 'Things that may manually need installing/updating:'
log_info '  * Update gitignore: concat_multiple_gitignores'
log_info '  * Set .localrc per host'
log_info '  * Verify autojump, cheat & tmux works'
if [ "$OS" = Darwin ]; then
  log_info '  * Brave Browser: https://brave.com/download'
  log_info '  * Login shell is zsh by default; switch to Homebrew bash: chsh -s /opt/homebrew/bin/bash'
  log_info '    (add it to /etc/shells first). /bin/bash is 3.2 and too old for mapfile in some functions.'
else
  log_info '  * Brave Browser: https://brave.com/linux/'
  log_info '  ** Enable Uphold Wallet'
  log_info '  * Modify swappiness in /etc/sysctl.conf, vm.swappiness=10'
fi

if [ -n "$FAILURES" ]; then
  log_error "Some installs failed:$FAILURES"
  exit 1
fi
