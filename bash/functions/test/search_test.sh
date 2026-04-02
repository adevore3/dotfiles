#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/search/all_commands_grep.func"
source "${DOTFILES}/bash/functions/search/eg.func"
source "${DOTFILES}/bash/functions/search/egv.func"
source "${DOTFILES}/bash/functions/search/find_grep.func"
source "${DOTFILES}/bash/functions/search/lsgrep.func"

test_all_commands_grep_help_flag() {
    local result=$(all_commands_grep --help)
    assert_contains "SYNOPSIS" "$result" "all_commands_grep --help should show usage"
}

test_all_commands_grep_h_flag() {
    local result=$(all_commands_grep -h)
    assert_contains "SYNOPSIS" "$result" "all_commands_grep -h should show usage"
}

test_eg_help_flag() {
    local result=$(eg --help)
    assert_contains "SYNOPSIS" "$result" "eg --help should show usage"
}

test_eg_h_flag() {
    local result=$(eg -h)
    assert_contains "SYNOPSIS" "$result" "eg -h should show usage"
}

test_egv_help_flag() {
    local result=$(egv --help)
    assert_contains "SYNOPSIS" "$result" "egv --help should show usage"
}

test_egv_h_flag() {
    local result=$(egv -h)
    assert_contains "SYNOPSIS" "$result" "egv -h should show usage"
}

test_find_grep_help_flag() {
    local result=$(find_grep --help)
    assert_contains "SYNOPSIS" "$result" "find_grep --help should show usage"
}

test_find_grep_h_flag() {
    local result=$(find_grep -h)
    assert_contains "SYNOPSIS" "$result" "find_grep -h should show usage"
}

test_lsgrep_help_flag() {
    local result=$(lsgrep --help)
    assert_contains "SYNOPSIS" "$result" "lsgrep --help should show usage"
}

test_lsgrep_h_flag() {
    local result=$(lsgrep -h)
    assert_contains "SYNOPSIS" "$result" "lsgrep -h should show usage"
}

log_info "Running search function tests"
test_all_commands_grep_help_flag
test_all_commands_grep_h_flag
test_eg_help_flag
test_eg_h_flag
test_egv_help_flag
test_egv_h_flag
test_find_grep_help_flag
test_find_grep_h_flag
test_lsgrep_help_flag
test_lsgrep_h_flag
log_info "All search function tests passed!"
