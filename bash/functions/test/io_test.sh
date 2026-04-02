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

test_cap_help_flag
test_ret_help_flag

echo "All io tests passed!"
