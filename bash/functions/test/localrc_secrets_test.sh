#!/usr/bin/env bash

# Tests bashrc's two per-host config lines against a scratch HOME.
#
# Both are sed'd out of bash/bashrc rather than reimplemented, so this cannot drift from what startup runs. The
# ordering is the point: ~/.localrc is a *tracked* symlink into the repo, so credentials live in
# ~/.localrc.secrets, which has to be sourced second or a tracked default would win over a real secret. Getting
# that backwards is silent — the variable is set either way, just to the wrong value.
#
# Nothing here touches the real ~/.localrc; every case runs against a throwaway HOME with dummy values.

source "${DOTFILES}/bash/functions/test/test_utils.sh"

BASHRC="${DOTFILES}/bash/bashrc"

# Single quotes are deliberate: the patterns must reach sed as the literal text in bashrc, unexpanded.
# shellcheck disable=SC2016
LOCALRC_LINES=$(sed -n '/^if \[ -a ~\/\.localrc \]/p;/^if \[ -r ~\/\.localrc\.secrets \]/p' "$BASHRC")

if [ "$(printf '%s\n' "$LOCALRC_LINES" | grep -c .)" -ne 2 ]; then
  echo "FAIL: expected both localrc lines in $BASHRC, found:"
  printf '%s\n' "$LOCALRC_LINES"
  exit 1
fi

echo "=== localrc / localrc.secrets Tests ==="

WORK_DIR=$(mktemp -d)
trap 'chmod -R u+rwX "$WORK_DIR" 2> /dev/null; rm -rf "$WORK_DIR"' EXIT

# Runs the real lines with HOME pointed at a scratch dir, and reports what the variables ended up as.
# Args: <localrc contents or --none> <secrets contents or --none>
function source_result() {
  (
    HOME="$WORK_DIR"
    rm -f "$WORK_DIR/.localrc" "$WORK_DIR/.localrc.secrets"
    [ "$1" = "--none" ] || printf '%s\n' "$1" > "$WORK_DIR/.localrc"
    [ "$2" = "--none" ] || { printf '%s\n' "$2" > "$WORK_DIR/.localrc.secrets"; chmod 600 "$WORK_DIR/.localrc.secrets"; }
    [ -n "${3:-}" ] && chmod "$3" "$WORK_DIR/.localrc.secrets"

    eval "$LOCALRC_LINES"
    printf '%s|%s' "${FROM_LOCALRC:-unset}" "${A_TOKEN:-unset}"
  )
}

assert_equals "unset|unset" "$(source_result --none --none)" \
  "neither file present is a silent no-op"

assert_equals "yes|unset" "$(source_result 'FROM_LOCALRC=yes' --none)" \
  "~/.localrc alone is sourced"

assert_equals "unset|secret" "$(source_result --none 'A_TOKEN=secret')" \
  "~/.localrc.secrets alone is sourced"

assert_equals "yes|secret" "$(source_result 'FROM_LOCALRC=yes' 'A_TOKEN=secret')" \
  "both files are sourced together"

# The ordering that matters. A tracked localrc_<host> may well set a default; the untracked secret must win.
assert_equals "yes|real" "$(source_result 'FROM_LOCALRC=yes
A_TOKEN=placeholder' 'A_TOKEN=real')" \
  "~/.localrc.secrets is sourced last, so a secret overrides a tracked default"

# -r, not -f: an unreadable file must be skipped rather than emitting a "Permission denied" on every new shell.
# Root can read it regardless, so there is nothing to assert there.
if [ "$(id -u)" -ne 0 ]; then
  output=$(source_result --none 'A_TOKEN=secret' 000 2>&1)
  assert_equals "unset|unset" "$output" "an unreadable ~/.localrc.secrets is skipped without an error"
fi

echo ""
echo "All localrc secrets tests passed!"
