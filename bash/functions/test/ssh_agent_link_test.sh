#!/usr/bin/env bash

# Tests bashrc's SSH-agent symlink logic against real ssh-agent processes.
#
# The logic is lifted out of bash/bashrc by sed rather than reimplemented, so this cannot drift from what
# actually runs at startup. It is tested here because the bug it guards against is invisible to inspection: on
# macOS `SSH_AUTH_SOCK` always names a launchd agent that is usually *empty*, so the old `-S` test happily
# repointed the shared symlink at a useless agent and the local-agent fallback — gated on the socket merely
# existing — then skipped itself. Every push failed with "Permission denied (publickey)" and nothing looked wrong.

source "${DOTFILES}/bash/functions/test/test_utils.sh"

BASHRC="${DOTFILES}/bash/bashrc"

# The helper and the adopt block, verbatim from bashrc.
eval "$(sed -n '/^_ssh_agent_has_keys()/,/^}/p' "$BASHRC")"
# Single quotes are deliberate: the pattern must reach sed as the literal text in bashrc, unexpanded.
# shellcheck disable=SC2016
ADOPT_BLOCK=$(sed -n '/^if \[\[ -S "\${SSH_AUTH_SOCK:-}"/,/^fi$/p' "$BASHRC")
# The fallback's retire step, which kills a previous keyless agent of ours before rebinding its socket. Ends at
# the `fi` indented four spaces; the `fi` inside it sits at twelve.
# shellcheck disable=SC2016
RETIRE_BLOCK=$(sed -n '/^    if \[ -r "\${SSH_OWN_AGENT_PIDFILE}" \]/,/^    fi$/p' "$BASHRC")

if [ -z "$ADOPT_BLOCK" ] || [ -z "$RETIRE_BLOCK" ] || ! type _ssh_agent_has_keys > /dev/null 2>&1; then
  echo "FAIL: could not extract the agent logic from $BASHRC — did a block move or get reworded?"
  exit 1
fi

echo "=== SSH Agent Link Tests ==="

WORK_DIR=$(mktemp -d)
AGENT_PIDS=""
# Kill only the agents this test starts, never the user's.
cleanup() {
  local pid
  for pid in $AGENT_PIDS; do kill "$pid" 2> /dev/null; done
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# A throwaway passphrase-less key, so ssh-add never prompts.
ssh-keygen -q -t ed25519 -N "" -f "$WORK_DIR/key" -C throwaway

start_agent() {
  local sock="$1"
  eval "$(ssh-agent -a "$sock")" > /dev/null
  AGENT_PIDS="$AGENT_PIDS $SSH_AGENT_PID"
}

KEYED_SOCK="$WORK_DIR/keyed.sock"
EMPTY_SOCK="$WORK_DIR/empty.sock"
start_agent "$KEYED_SOCK"
SSH_AUTH_SOCK="$KEYED_SOCK" ssh-add "$WORK_DIR/key" > /dev/null 2>&1
start_agent "$EMPTY_SOCK"

# --- _ssh_agent_has_keys classification ---

assert_equals "yes" "$(_ssh_agent_has_keys "$KEYED_SOCK" && echo yes || echo no)" \
  "has_keys: true for an agent holding an identity"
assert_equals "no" "$(_ssh_agent_has_keys "$EMPTY_SOCK" && echo yes || echo no)" \
  "has_keys: false for a reachable but empty agent"
assert_equals "no" "$(_ssh_agent_has_keys "$WORK_DIR/nonexistent.sock" && echo yes || echo no)" \
  "has_keys: false for a missing socket"
assert_equals "no" "$(_ssh_agent_has_keys "" && echo yes || echo no)" \
  "has_keys: false for an empty argument"

# A plain file is not a socket; -S must reject it before ssh-add is ever run.
: > "$WORK_DIR/regular_file"
assert_equals "no" "$(_ssh_agent_has_keys "$WORK_DIR/regular_file" && echo yes || echo no)" \
  "has_keys: false for a regular file"

# --- the adopt decision ---

# Runs the real block with a scratch link, and reports which socket the link ends up on.
adopt_result() {
  local inherited="$1" link_target="$2"
  local SSH_AUTH_SOCK_LINK="$WORK_DIR/link"
  # Both locals are read by the eval'd block below, not by this function directly.
  # shellcheck disable=SC2034
  local SSH_AUTH_SOCK="$inherited"
  rm -f "$SSH_AUTH_SOCK_LINK"
  [ -n "$link_target" ] && ln -sf "$link_target" "$SSH_AUTH_SOCK_LINK"
  eval "$ADOPT_BLOCK"
  basename "$(readlink "$SSH_AUTH_SOCK_LINK" 2> /dev/null || echo none)"
}

# The regression. A new macOS login shell inherits the empty launchd agent; adopting it would break ssh for
# every already-running tmux pane, since they all read this one link.
assert_equals "keyed.sock" "$(adopt_result "$EMPTY_SOCK" "$KEYED_SOCK")" \
  "adopt: an empty inherited agent does not clobber a keyed link"

# The case the link exists for: a reconnected `ssh -A` brings a fresh keyed socket, which must win.
assert_equals "keyed.sock" "$(adopt_result "$KEYED_SOCK" "$EMPTY_SOCK")" \
  "adopt: a keyed inherited agent replaces an empty link"

assert_equals "keyed.sock" "$(adopt_result "$KEYED_SOCK" "$KEYED_SOCK")" \
  "adopt: a keyed inherited agent is adopted over a keyed link"

# Nothing better on offer: take the empty agent so the link is at least live, and let the fallback add a key.
assert_equals "empty.sock" "$(adopt_result "$EMPTY_SOCK" "$WORK_DIR/dead.sock")" \
  "adopt: an empty inherited agent replaces a dead link"

assert_equals "empty.sock" "$(adopt_result "$EMPTY_SOCK" "")" \
  "adopt: an empty inherited agent is taken when no link exists"

# --- the fallback gate ---
#
# The fallback must fire on a reachable-but-empty link. Gating on `-S` is what silently skipped it.

assert_equals "fires" "$(_ssh_agent_has_keys "$EMPTY_SOCK" && echo skipped || echo fires)" \
  "fallback: fires when the link points at an empty agent"
assert_equals "skipped" "$(_ssh_agent_has_keys "$KEYED_SOCK" && echo skipped || echo fires)" \
  "fallback: skipped when the link points at a keyed agent"

# --- retiring our own keyless agent ---
#
# The fallback rebinds a fixed socket, so it must kill the agent already on that path or it strands one per
# attempt -- the very leak the fixed socket was introduced to stop. The subtlety is that a socket cannot name a
# process: `ssh-agent -k` kills whatever SSH_AGENT_PID says and ignores SSH_AUTH_SOCK entirely, and a fresh login
# shell has no SSH_AGENT_PID. Hence the pidfile, and hence these tests.

alive() { kill -0 "$1" 2> /dev/null && echo alive || echo gone; }

# Runs the real retire fragment against a scratch pidfile.
retire_with_pidfile() {
  local SSH_OWN_AGENT_PIDFILE="$WORK_DIR/own_pid"
  if [ "$1" = "--none" ]; then rm -f "$SSH_OWN_AGENT_PIDFILE"; else printf '%s\n' "$1" > "$SSH_OWN_AGENT_PIDFILE"; fi
  eval "$RETIRE_BLOCK"
}

# The regression, stated as a test: aiming -k at the socket does nothing, because SSH_AGENT_PID is what it reads.
# This is the exact call the fallback used to make, and it left a live agent behind for the following rm to orphan.
start_agent "$WORK_DIR/orphan.sock"
orphan_pid="$SSH_AGENT_PID"
( unset SSH_AGENT_PID; SSH_AUTH_SOCK="$WORK_DIR/orphan.sock" ssh-agent -k > /dev/null 2>&1 )
assert_equals "alive" "$(alive "$orphan_pid")" \
  "retire: -k aimed at a socket does not kill the agent, so the pid has to be recorded"

# And the fix: given the pid we wrote, the agent really goes.
retire_with_pidfile "$orphan_pid"
assert_equals "gone" "$(alive "$orphan_pid")" "retire: kills the agent named by the pidfile"
assert_equals "gone" "$([ -S "$WORK_DIR/orphan.sock" ] && echo alive || echo gone)" \
  "retire: the killed agent takes its socket with it"

# A pid can be reused between shells, and -k does a bare kill without checking its target -- so anything that is
# not still an ssh-agent must be left alone. This test's own shell is the handiest non-agent pid there is.
retire_with_pidfile "$$"
assert_equals "alive" "$(alive "$$")" "retire: refuses to kill a pid that is no longer an ssh-agent"

# A truncated or hand-mangled pidfile, and a missing one, must both be no-ops rather than errors.
output=$(retire_with_pidfile "not-a-pid" 2>&1)
assert_equals "" "$output" "retire: a non-numeric pidfile is ignored silently"
output=$(retire_with_pidfile "" 2>&1)
assert_equals "" "$output" "retire: an empty pidfile is ignored silently"
output=$(retire_with_pidfile --none 2>&1)
assert_equals "" "$output" "retire: a missing pidfile is ignored silently"

# --- the [ -t 0 ] guard ---
#
# The negative case only, which is the one that leaked: with no controlling terminal the fallback must not start
# an agent, because `ssh-add` would print a passphrase prompt nothing can answer and strand the agent behind it.
# The positive case needs a pty, and `script`'s syntax differs between util-linux and BSD — the exact portability
# trap this repo documents — so it is left to real terminal use rather than branching on the platform here.

# Stubs on a synthetic PATH, so nothing real is spawned and the guard's decision is observable either way.
STUB_BIN="$WORK_DIR/stub_bin"
mkdir -p "$STUB_BIN"
printf '#!/bin/sh\necho spawned >> "%s/agent_started"\necho "SSH_AGENT_PID=1; export SSH_AGENT_PID;"\n' \
  "$WORK_DIR" > "$STUB_BIN/ssh-agent"
printf '#!/bin/sh\necho added >> "%s/ssh_add_ran"\n' "$WORK_DIR" > "$STUB_BIN/ssh-add"
chmod +x "$STUB_BIN/ssh-agent" "$STUB_BIN/ssh-add"

# The guard as bashrc spells it, against a socket with no keys.
tty_guard_spawns() {
  rm -f "$WORK_DIR/agent_started" "$WORK_DIR/ssh_add_ran"
  PATH="$STUB_BIN:$PATH" "$BASH" -c '
    own_sock="$1"
    # Mirrors bashrc: no keys on our own socket AND a terminal on stdin.
    if ! { [ -S "$own_sock" ] && ssh-add -l > /dev/null 2>&1; } && [ -t 0 ]; then
      eval "$(ssh-agent -a "$own_sock")" > /dev/null
      ssh-add
    fi
  ' _ "$WORK_DIR/guard.sock" < /dev/null
  [ -f "$WORK_DIR/agent_started" ] && echo spawned || echo skipped
}

assert_equals "skipped" "$(tty_guard_spawns)" \
  "tty guard: no agent is started when stdin is not a terminal"
assert_equals "no" "$([ -f "$WORK_DIR/ssh_add_ran" ] && echo yes || echo no)" \
  "tty guard: ssh-add is not run when stdin is not a terminal"

echo ""
echo "All ssh agent link tests passed!"
