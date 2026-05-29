#!/bin/bash
# Verifies setup.sh creates a resolvable directory symlink at the computed memory path,
# and that an existing empty real memory dir is replaced (not nested into).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

FAKE_HOME="$(mktemp -d)"
SLUG="${ROOT//\//-}"
TARGET="$FAKE_HOME/.claude/projects/${SLUG}/memory"

# Pre-create an existing empty real memory dir to prove it gets replaced by the symlink.
mkdir -p "$TARGET"

HOME="$FAKE_HOME" bash "$ROOT/claude/setup.sh" >/dev/null

assert_equals "symlink" "$([ -L "$TARGET" ] && echo symlink || echo notlink)" "memory target is a symlink"
assert_equals "$ROOT/claude/memory/dotfiles" "$(readlink "$TARGET")" "symlink points at repo memory dir"
assert_equals "dir" "$([ -d "$TARGET" ] && echo dir || echo no)" "symlink resolves to a directory"

rm -rf "$FAKE_HOME"
echo "setup memory test passed."
