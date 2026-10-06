#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/io/cap.func"
source "${DOTFILES}/bash/functions/io/ret.func"

test_cap_help_flag() {
    local result=$(cap --help)
    assert_contains "SYNOPSIS" "$result" "cap --help should show usage"
}

test_ret_help_flag() {
    local result=$(ret --help)
    assert_contains "Usage:" "$result" "ret --help should show usage"
}

# cap/ret round trips go through the real /tmp, which is the only place cap writes. Every capture this
# suite makes is prefixed, so it can never collide with a real /tmp/*.out of the user's, and cleanup
# removes them by that prefix. Deliberately *not* an array of paths appended to by the helper below:
# `name=$(capture ...)` runs it in a command substitution, so any array it mutates is a subshell copy and
# the files survive the trap. aws_save_token_test.sh had exactly that bug, which is how its fixture
# credentials ended up left behind in a real capture file.
readonly CAPTURE_PREFIX=iotest
scratch=$(mktemp -d)

cleanup() {
    rm -f /tmp/"$CAPTURE_PREFIX"-*.out
    rm -rf "$scratch"
}
trap cleanup EXIT

capture() {
    local name="$CAPTURE_PREFIX-$1"
    echo "$2" | cap -q "$name"
    echo "$name"
}

test_cap_writes_and_ret_reads_back() {
    local name
    name=$(capture one "first body")

    assert_equals "first body" "$(ret "$name")" "ret reads back what cap wrote"
    assert_equals "yes" "$(ret -e "$name")" "ret -e finds the capture"
}

test_ret_partial_match() {
    local name
    name=$(capture partialmatch "matched body")

    # ret falls back to a substring match on the filename when there is no exact hit
    assert_equals "matched body" "$(ret iotest-partialmat)" "ret matches a capture by name fragment"
}

test_ret_missing_capture_fails() {
    local output status
    # stdin closed: a bare `cat` with no filename would read it, which is the bug this guards
    output=$(ret iotest-no-such-capture 2>&1 < /dev/null) && status=0 || status=$?

    assert_contains "Unable to find an output file" "$output" "ret reports an unresolvable name"
    assert_equals "1" "$status" "ret returns non-zero for an unresolvable name"
}

# A stub `ls` that deletes the group column from long format, which is what GNU ls does when it is handed
# -G (BSD ls reads the same flag as "colorize"). Pinned with a stub rather than by aliasing the real ls,
# because whether that reproduces depends on which ls the host has first on PATH - it does not on a BSD-ls
# mac, so the test would pass for the wrong reason exactly where it needs to fail. Short-format calls pass
# straight through: the point of the assertion is that `ret -f` never looks at long format at all.
make_gnu_style_ls_stub() {
    mkdir -p "$scratch/bin"
    cat > "$scratch/bin/ls" <<'STUB'
#!/bin/bash
real=$(PATH=/usr/bin:/bin command -v ls)
for arg in "$@"; do
    case "$arg" in
        -*l*)
            "$real" "$@" | awk '{ $4=""; print }'
            exit $?
            ;;
    esac
done
"$real" "$@"
STUB
    chmod +x "$scratch/bin/ls"
}

test_ret_f_does_not_parse_long_format() {
    local name output
    name=$(capture freshest "freshest body")
    make_gnu_style_ls_stub

    # Both dimensions at once: the stub reshapes long format, and the alias is what feeds GNU ls the -G
    # that makes it do so in a real interactive shell.
    shopt -s expand_aliases
    alias ls='ls -G'
    output=$(PATH="$scratch/bin:$PATH" ret -f 1)
    unalias ls

    assert_equals "freshest body" "$output" "ret -f 1 returns the newest capture when ls -l is reshaped"
}

test_ret_f_multiple_files_are_all_returned() {
    local output
    capture older "older body" > /dev/null
    sleep 1
    capture newer "newer body" > /dev/null

    output=$(ret -f 2)
    assert_contains "newer body" "$output" "ret -f 2 includes the newest capture"
    assert_contains "older body" "$output" "ret -f 2 also includes the second newest"
}

test_ret_f_rejects_a_non_count() {
    local output status
    output=$(ret -f abc 2>&1) && status=0 || status=$?

    assert_contains "takes a count" "$output" "ret -f rejects a non-numeric count"
    assert_equals "1" "$status" "ret -f returns non-zero for a non-numeric count"
}

test_cap_help_flag
test_ret_help_flag
test_cap_writes_and_ret_reads_back
test_ret_partial_match
test_ret_missing_capture_fails
test_ret_f_does_not_parse_long_format
test_ret_f_multiple_files_are_all_returned
test_ret_f_rejects_a_non_count

echo "All io tests passed!"
