#!/usr/bin/env bash
# Symlinks Claude config whose target path can't be hardcoded — the per-project memory
# dir, keyed by the absolute repo path. Fixed-path files are handled by dotbot link:
# entries in install.conf.yaml. Also prunes skill links orphaned by a rename.
# Idempotent; safe to re-run.
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

# Prune skill links this repo orphaned — a symlink into claude/skills/ whose source is gone because the
# skill was renamed or deleted (e.g. my-mrs -> gitlab). Dotbot creates these links but its `clean` only
# sweeps ~ and ~/.config, so a rename otherwise leaves a dangling link that Claude still tries to load.
# Only touch links pointing into OUR skills dir; other repos' skills (the indeed submodule's) are theirs
# to prune. Matches the same loop in indeed/claude/setup.sh.
for link in "$HOME/.claude/skills"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$DOTFILES/claude/skills"/*)
      [ -e "$link" ] || { rm -f "$link"; echo "Pruned stale skills/$(basename "$link")"; }
      ;;
  esac
done

# Hand off to the indeed submodule's own setup when it's checked out (keeps Indeed-specific wiring
# in that repo; this is just a conditional invocation, no Indeed content in the public dotfiles).
if [ -f "$DOTFILES/indeed/claude/setup.sh" ]; then
  ( cd "$DOTFILES/indeed/claude" && bash setup.sh )
fi
