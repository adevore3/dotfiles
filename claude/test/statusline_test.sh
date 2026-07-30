#!/bin/bash
# Tests statusline-command.sh's directory rendering: $HOME collapses to ~ for display, anything else is
# printed as-is. Runs against a throwaway HOME, since the script sources ~/.claude/hooks/session-name.sh.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The statusline sources session-name.sh through ~, so the fake HOME needs it on that path too.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude/hooks"
ln -s "$ROOT/claude/hooks/session-name.sh" "$FAKE_HOME/.claude/hooks/session-name.sh"

statusline() {
  printf '{"cwd":"%s","session_id":"sess01"}' "$1" \
    | HOME="$FAKE_HOME" bash "$ROOT/claude/statusline-command.sh"
}

out="$(statusline "$FAKE_HOME/proj")"
assert_contains "(~/proj" "$out" "a directory under \$HOME is shown with ~"
assert_equals "0" "$(printf '%s' "$out" | grep -c "$FAKE_HOME/proj")" "the absolute \$HOME prefix is not printed"

out="$(statusline "$FAKE_HOME")"
assert_contains "(~)" "$out" "\$HOME itself is just ~"

out="$(statusline "/tmp/elsewhere")"
assert_contains "(/tmp/elsewhere" "$out" "a directory outside \$HOME is printed as-is"

# A sibling sharing the $HOME prefix must not be mangled into "~2" by a naive prefix strip.
out="$(statusline "${FAKE_HOME}2/proj")"
assert_contains "(${FAKE_HOME}2/proj" "$out" "a sibling of \$HOME keeps its real path"

echo "All statusline tests passed"
