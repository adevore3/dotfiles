#!/bin/bash
# Tests for the settings fragment merge: delegates the merge semantics to python
# (settings_merge_test.py), then drives claude/setup.sh end-to-end against a throwaway HOME to prove the
# wiring actually applies the fragments and is idempotent — only a shell can check that part.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not available -> skipping settings_merge tests"; exit 0
fi

echo "--- merge unit tests (python) ---"
if ! (cd "$DIR" && python3 -m unittest settings_merge_test 2>&1 | tail -4); then
  echo "✗ python unit tests failed"; exit 1
fi

echo "--- setup.sh end-to-end ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"

SETTINGS="$FAKE_HOME/.claude/settings.json"
STATE="$FAKE_HOME/.claude/.dotfiles-settings.base.state.json"

# A live file holding something only a third party would have written, to prove we leave it alone.
cat > "$SETTINGS" <<'JSON'
{
  "theme": "light",
  "extraKnownMarketplaces": { "someone-elses": { "source": { "source": "github", "repo": "x/y" } } },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "their-hook.sh" } ] } ] }
}
JSON

run_setup() { HOME="$FAKE_HOME" DOTFILES="$ROOT" bash "$ROOT/claude/setup.sh" 2>&1; }

out="$(run_setup)"
assert_contains "settings.json" "$out" "setup.sh reports the settings merge"

# The base fragment's content landed.
assert_equals "0" "$(python3 -c "
import json,sys
s=json.load(open('$SETTINGS'))
sys.exit(0 if 'Bash(ls:*)' in s['permissions']['allow'] else 1)
"; echo $?)" "a base allow rule is present after setup"

# Third-party content survived.
assert_equals "their-hook.sh" "$(python3 -c "
import json
s=json.load(open('$SETTINGS'))
print(s['hooks']['Stop'][0]['hooks'][0]['command'])
")" "a foreign Stop hook is untouched"
assert_equals "someone-elses" "$(python3 -c "
import json
print(list(json.load(open('$SETTINGS'))['extraKnownMarketplaces'])[0])
")" "a foreign marketplace entry is untouched"

# A seeded pref already set by the user is not reverted.
assert_equals "light" "$(python3 -c "import json; print(json.load(open('$SETTINGS'))['theme'])")" \
  "setup.sh does not revert a theme the user changed"

# Idempotent: a second run changes nothing.
before="$(cat "$SETTINGS")"
out="$(run_setup)"
assert_equals "$before" "$(cat "$SETTINGS")" "a second setup.sh run leaves settings byte-identical"
assert_contains "already current" "$out" "the second run reports no change"

# State was recorded, and holds the merge block rather than the seeded prefs.
assert_equals "yes" "$([ -s "$STATE" ] && echo yes || echo no)" "the state file was written"
assert_equals "no" "$(python3 -c "
import json
print('yes' if 'theme' in json.load(open('$STATE')) else 'no')
")" "seeded prefs stay out of state so removal never deletes them"

# The live file must not be a symlink into the repo: that is what leaked harness writes.
assert_equals "no" "$([ -L "$SETTINGS" ] && echo yes || echo no)" "setup.sh leaves a real file, not a link"

echo "All settings_merge tests passed"
