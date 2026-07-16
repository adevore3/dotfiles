#!/usr/bin/env bash
# Symlinks Claude config whose target path can't be hardcoded — the per-project memory
# dir, keyed by the absolute repo path. Fixed-path files are handled by dotbot link:
# entries in install.conf.yaml. Idempotent; safe to re-run.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

link_memory() {
  local name="$1"                                   # repo dir under claude/memory/
  local repo_path="$2"                              # absolute path the repo is checked out at
  local slug target
  slug="${repo_path//\//-}"                           # /home/adevore/dotfiles -> -home-adevore-dotfiles
  target="$HOME/.claude/projects/${slug}/memory"

  mkdir -p "$(dirname "$target")"
  # Replace an existing non-symlink dir (move aside if it has contents).
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    rmdir "$target" 2>/dev/null || mv "$target" "${target}.bak-$(date +%s)"
  fi
  ln -sfn "$DOTFILES/claude/memory/${name}" "$target"
  if [ -d "$target" ]; then
    echo "Linked claude/memory/${name} -> $target"
  else
    echo "BROKEN: $target does not resolve" >&2
    return 1
  fi
}

# Non-Indeed repos whose memory we track: <memory-dir-name> <checkout-path>
link_memory dotfiles "$DOTFILES"
# Global/default project (Claude runs with cwd=$HOME): personal, non-repo memory.
link_memory home "$HOME"

# Hand off to the indeed submodule's own setup when it's checked out (keeps Indeed-specific wiring
# in that repo; this is just a conditional invocation, no Indeed content in the public dotfiles).
[ -f "$DOTFILES/indeed/claude/setup.sh" ] && ( cd "$DOTFILES/indeed/claude" && bash setup.sh )
