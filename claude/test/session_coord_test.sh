#!/bin/bash
# Tests session_coord.sh: the cross-session collision-awareness engine (PreToolUse/PostToolUse). Verifies it warns only
# on same-resource contention from another worktree, writes/removes claim files, prunes stale claims, layers the
# description (note override), and no-ops with no config / on non-Bash tools. Uses temp registry + config dirs; never
# touches the real ~/.claude state.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DOTFILES:-$(cd "$DIR/../.." && pwd)}"
source "$ROOT/bash/functions/test/test_utils.sh"
ENGINE="$DIR/../hooks/session_coord.sh"

assert_not_contains() {
  if [[ "$2" != *"$1"* ]]; then echo "✓ $3"; else echo "✗ $3"; echo "  Expected NOT to contain: $1"; echo "  Got: $2"; exit 1; fi
}

# Fresh temp registry + config + a work cwd for each case. WORK is a non-git dir, so the engine falls back to cwd for
# the worktree key and leaves branch empty -- fine for these tests.
new_env() {
  BASE="$(mktemp -d)"
  REG="$BASE/registry"; CONF="$BASE/conf"; WORK="$BASE/work"
  mkdir -p "$CONF" "$WORK" "$REG"
  printf 'publocal\tgradlew[[:space:]].*\\bpublocal\\b\tRaces the shared publocal-5.lock.\n' >"$CONF/t.conf"
  printf 'spark-run\t\\b(indeed-spark-run|isr|iss)\\b\n' >>"$CONF/t.conf"
}
run() {  # run <pre|post> <json>  (uses $REG/$CONF/$WORK/$TTL)
  printf '%s' "$2" | CLAUDE_SESSION_COORD_CONF="$CONF" CLAUDE_SESSION_COORD_DIR="$REG" \
    CLAUDE_SESSION_COORD_TTL="${TTL:-3600}" bash "$ENGINE" "$1"
}
bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s","session_id":"%s","transcript_path":""}' "$1" "$WORK" "${2:-sessAAA}"; }
seed_claim() {  # seed_claim <resource> <wtkey> <branch> <basename> <desc> <start_epoch>
  cat >"$REG/claim.$1.$2" <<EOF
resource=$1
wtkey=$2
worktree=/work/$4
branch=$3
basename=$4
session_id=sessOTHER
description=$5
start_epoch=$6
EOF
}

now=$(date +%s)

# 1. No config -> silent no-op, nothing written.
new_env; rm -f "$CONF"/*.conf
out=$(run pre "$(bash_json 'gradlew publocal')")
assert_equals "" "$out" "no config: no output"
assert_equals "0" "$(find "$REG" -name 'claim.*' 2>/dev/null | wc -l | tr -d ' ')" "no config: no claim written"

# 2. Match + no other claim -> no warning, own claim written with resource field.
new_env
out=$(run pre "$(bash_json 'gradlew publocal --offline')")
assert_not_contains "Another Claude session" "$out" "solo publocal: no warning"
claim=$(find "$REG" -name 'claim.publocal.*' | head -n1)
assert_contains "resource=publocal" "$(cat "$claim")" "solo publocal: claim written"

# 3. Match + another worktree's active claim, same resource -> warning with its identity + hint.
new_env
seed_claim publocal otherkey "adevore/DIRP-4700/foo" "wt-dirp-4700" "verify DIRP-4580 3.5.3 compat" "$now"
out=$(run pre "$(bash_json 'gradlew publocal')")
assert_contains "Another Claude session" "$out" "contention: warns"
assert_contains "wt-dirp-4700" "$out" "contention: names other worktree"
assert_contains "adevore/DIRP-4700/foo" "$out" "contention: names other branch"
assert_contains "verify DIRP-4580 3.5.3 compat" "$out" "contention: includes other description"
assert_contains "publocal-5.lock" "$out" "contention: includes the resource hint"

# 4. Another claim but DIFFERENT resource class -> no warning.
new_env
seed_claim spark-run otherkey "adevore/DIRP-9/x" "wt-9" "" "$now"
out=$(run pre "$(bash_json 'gradlew publocal')")
assert_not_contains "Another Claude session" "$out" "different resource: no warning"

# 5. post removes only this worktree's matching claim.
new_env
run pre "$(bash_json 'gradlew publocal')" >/dev/null
seed_claim publocal otherkey "b" "wt-o" "" "$now"
run post "$(bash_json 'gradlew publocal')" >/dev/null
mine=$(find "$REG" -name 'claim.publocal.*' | grep -vc otherkey)
assert_equals "0" "$mine" "post: own claim removed"
assert_equals "1" "$(find "$REG" -name 'claim.publocal.otherkey' | wc -l | tr -d ' ')" "post: other claim untouched"

# 6. Stale claim (older than TTL) is pruned on the next pre, so it produces no warning.
new_env; TTL=100
seed_claim publocal otherkey "b" "wt-stale" "" "$((now - 9999))"
out=$(run pre "$(bash_json 'gradlew publocal')")
unset TTL
assert_not_contains "Another Claude session" "$out" "stale: no warning"
assert_equals "0" "$(find "$REG" -name 'claim.publocal.otherkey' | wc -l | tr -d ' ')" "stale: pruned"

# 7. Description layering: a note file overrides (used as this session's own claim description).
new_env
wtkey_raw="$WORK"; wtkey="${wtkey_raw//\//_}"
printf 'my hand-set note' >"$REG/note.$wtkey" 2>/dev/null || { mkdir -p "$REG"; printf 'my hand-set note' >"$REG/note.$wtkey"; }
run pre "$(bash_json 'gradlew publocal')" >/dev/null
claim=$(find "$REG" -name 'claim.publocal.*' | grep -v '\.otherkey' | head -n1)
assert_contains "description=my hand-set note" "$(cat "$claim")" "note override becomes description"

# 7b. session_note helper writes a note the engine then resolves as the description (end-to-end, same wtkey).
source "$ROOT/claude/functions/session_note.func"
new_env
( cd "$WORK" && CLAUDE_SESSION_COORD_DIR="$REG" session_note "note via helper" >/dev/null )
run pre "$(bash_json 'gradlew publocal')" >/dev/null
claim=$(find "$REG" -name 'claim.publocal.*' | grep -v '\.otherkey' | head -n1)
assert_contains "description=note via helper" "$(cat "$claim")" "session_note helper feeds the description"
( cd "$WORK" && CLAUDE_SESSION_COORD_DIR="$REG" session_note --clear >/dev/null )
assert_equals "0" "$(find "$REG" -name 'note.*' | wc -l | tr -d ' ')" "session_note --clear removes the note"

# 8. Non-Bash tool -> no-op.
new_env
out=$(run pre '{"tool_name":"Read","tool_input":{"file_path":"/x"},"cwd":"'"$WORK"'","session_id":"s"}')
assert_equals "" "$out" "non-Bash: no output"
assert_equals "0" "$(find "$REG" -name 'claim.*' 2>/dev/null | wc -l | tr -d ' ')" "non-Bash: nothing written"

echo "All session_coord tests passed."
