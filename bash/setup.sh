#!/usr/bin/env bash

# Links the per-host and per-platform config that dotbot cannot, because the *source* path has to be computed
# from `hostname`/`uname` rather than being fixed. Same division of labor as claude/setup.sh: fixed-path files
# are plain `link:` entries in install.conf.yaml; anything resolved at runtime lives here.
#
# Two jobs:
#   ~/.localrc            -> bash/localrc_<hostname -s>, else bash/localrc_<uname -s>
#   ~/.ssh/config.d/*.conf -> ssh/config.d/00-common.conf, plus 10-<uname -s>.conf when one exists
#
# Idempotent and safe to re-run; exits non-zero if any link it made fails to resolve.

set -uo pipefail

export DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "${DOTFILES}/bash/functions/log_utils.sh"

OS="$(uname -s)"
HOST="$(hostname -s 2> /dev/null || hostname)"
FAILURES=""

# link_config <source> <target>
#
# Replaces target with a symlink to source. A target that is already the right symlink is left alone. A target
# that is a *regular file* is only replaced when its content already matches, otherwise it is backed up first —
# the point of moving these into the repo is not to silently discard whatever the machine had.
function link_config() {
  local source_path="$1" target_path="$2"

  if [ ! -e "$source_path" ]; then
    log_error "  missing source $source_path"
    FAILURES="$FAILURES $(basename "$source_path")"
    return 1
  fi

  if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
    log_info "  already linked: $target_path"
    return 0
  fi

  if [ -f "$target_path" ] && [ ! -L "$target_path" ]; then
    if cmp -s "$source_path" "$target_path"; then
      log_info "  replacing identical regular file with a link: $target_path"
    else
      local backup="${target_path}.pre-dotfiles"
      log_warn "  $target_path differs from the repo copy; backing it up to $backup"
      mv "$target_path" "$backup" || { FAILURES="$FAILURES $(basename "$target_path")"; return 1; }
    fi
  fi

  mkdir -p "$(dirname "$target_path")"
  ln -sfn "$source_path" "$target_path" || { FAILURES="$FAILURES $(basename "$target_path")"; return 1; }
  log_info "  linked $target_path -> $source_path"
}

log_info "Linking per-host config (host=$HOST, os=$OS)"

# --- ~/.localrc ---
#
# Hostname first so two machines running the same OS can differ — the cloudvm and a Linux laptop are both
# Linux but want different content — with the platform file as the fallback.
LOCALRC_SOURCE=""
for candidate in "${DOTFILES}/bash/localrc_${HOST}" "${DOTFILES}/bash/localrc_${OS}"; do
  if [ -f "$candidate" ]; then
    LOCALRC_SOURCE="$candidate"
    break
  fi
done

if [ -n "$LOCALRC_SOURCE" ]; then
  link_config "$LOCALRC_SOURCE" "${HOME}/.localrc"
else
  log_info "  no localrc for this host; create bash/localrc_${HOST} or bash/localrc_${OS} to add one"
fi

# --- ~/.ssh/config.d/ ---
#
# The included files are tracked; ~/.ssh/config itself deliberately is NOT. OrbStack (and installers like it)
# append to that file, and symlinking it into the repo would mean every such write dirties the checkout.
log_info "Linking ssh config fragments"
mkdir -p "${HOME}/.ssh/config.d"
chmod 700 "${HOME}/.ssh" 2> /dev/null

link_config "${DOTFILES}/ssh/config.d/00-common.conf" "${HOME}/.ssh/config.d/00-common.conf"
if [ -f "${DOTFILES}/ssh/config.d/10-${OS}.conf" ]; then
  link_config "${DOTFILES}/ssh/config.d/10-${OS}.conf" "${HOME}/.ssh/config.d/10-${OS}.conf"
fi

# Prune fragments for other platforms, so a checkout shared across machines cannot leave a Darwin-only file
# behind on Linux, where `UseKeychain` aborts the entire ssh config rather than being ignored.
#
# A link into the repo is ours to delete; anything else is renamed instead, matching link_config's rule that the
# machine's own content is never silently discarded. `.pre-dotfiles` is outside the `*.conf` glob, so renaming
# defuses the fragment just as completely as removing it would.
for stale in "${HOME}"/.ssh/config.d/10-*.conf; do
  [ -e "$stale" ] || continue
  [ "$(basename "$stale")" = "10-${OS}.conf" ] && continue

  if [ -L "$stale" ]; then
    log_warn "  removing fragment for another platform: $stale"
    rm -f "$stale"
  else
    log_warn "  fragment for another platform is not ours; moving it to ${stale}.pre-dotfiles"
    mv "$stale" "${stale}.pre-dotfiles" || { FAILURES="$FAILURES $(basename "$stale")"; }
  fi
done

# --- the one line in ~/.ssh/config that pulls the above in ---
#
# Prepended, not appended: ssh takes the FIRST value it obtains for an option, so a fragment only wins if the
# Include precedes any conflicting Host block. A missing include path is silently ignored by ssh, which is why
# this is safe to ship on a host where the directory does not exist yet.
SSH_CONFIG="${HOME}/.ssh/config"
INCLUDE_LINE="Include ~/.ssh/config.d/*.conf"
if [ -f "$SSH_CONFIG" ] && grep -qF "$INCLUDE_LINE" "$SSH_CONFIG"; then
  log_info "  ~/.ssh/config already includes config.d"
else
  log_info "  prepending the config.d include to ~/.ssh/config"
  tmp_config="$(mktemp)" || exit 1
  {
    echo "# Added by dotfiles (bash/setup.sh): per-platform fragments, tracked in ssh/config.d/."
    echo "# Must precede any conflicting Host block — ssh uses the first value it obtains for an option."
    echo "$INCLUDE_LINE"
    echo
    [ -f "$SSH_CONFIG" ] && cat "$SSH_CONFIG"
  } > "$tmp_config"
  cat "$tmp_config" > "$SSH_CONFIG"
  rm -f "$tmp_config"
  chmod 600 "$SSH_CONFIG"
fi

# --- verify ---
log_info "Verifying links"
for link in "${HOME}/.localrc" "${HOME}/.ssh/config.d/00-common.conf" "${HOME}/.ssh/config.d/10-${OS}.conf"; do
  [ -L "$link" ] || continue
  if [ -e "$link" ]; then
    log_info "  OK: $link -> $(readlink "$link")"
  else
    log_error "  DANGLING: $link -> $(readlink "$link")"
    FAILURES="$FAILURES $(basename "$link")"
  fi
done

# The whole point is that ssh still parses; an unparseable config means no ssh at all.
if ! ssh -G example.com > /dev/null 2>&1; then
  log_error "  ssh cannot parse its config after linking:"
  ssh -G example.com 2>&1 | head -3
  FAILURES="$FAILURES ssh-config"
fi

if [ -n "$FAILURES" ]; then
  log_error "Some links failed:$FAILURES"
  exit 1
fi

log_info "Done."
