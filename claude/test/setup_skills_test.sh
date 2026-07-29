#!/bin/bash
# Verifies setup.sh prunes skill symlinks orphaned by a rename (my-mrs -> gitlab) without touching
# live links or links owned by another repo.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

FAKE_HOME="$(mktemp -d)"
SKILLS="$FAKE_HOME/.claude/skills"
mkdir -p "$SKILLS"

# 1. Dangling: points into our skills dir at a name that no longer exists (the rename we just did).
ln -s "$ROOT/claude/skills/my-mrs" "$SKILLS/my-mrs"
# 2. Live: points into our skills dir at a real skill.
ln -s "$ROOT/claude/skills/gitlab" "$SKILLS/gitlab"
# 3. Foreign and dangling: another repo's skill. Not ours to prune, even though it's broken. The name
#    must not match a real skill in any repo, or the indeed submodule's setup would relink over it.
FOREIGN="$(mktemp -d)"
ln -s "$FOREIGN/skills/not-our-skill" "$SKILLS/not-our-skill"

OUT="$(HOME="$FAKE_HOME" bash "$ROOT/claude/setup.sh" 2>&1)"

assert_equals "notlink" "$([ -L "$SKILLS/my-mrs" ] && echo link || echo notlink)" \
  "dangling my-mrs link is pruned"
assert_contains "Pruned stale skills/my-mrs" "$OUT" "prune is reported"

assert_equals "link" "$([ -L "$SKILLS/gitlab" ] && echo link || echo notlink)" \
  "live gitlab link is left alone"
assert_equals "dir" "$([ -d "$SKILLS/gitlab" ] && echo dir || echo no)" \
  "live gitlab link still resolves"

assert_equals "link" "$([ -L "$SKILLS/not-our-skill" ] && echo link || echo notlink)" \
  "another repo's dangling link is not pruned"

rm -rf "$FAKE_HOME" "$FOREIGN"
echo "setup skills test passed."
