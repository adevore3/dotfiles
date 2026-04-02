#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/navigation/mkcd.func"
source "${DOTFILES}/bash/functions/navigation/tre.func"
source "${DOTFILES}/bash/functions/navigation/up.func"

test_mkcd_help_flag() {
    local result=$(mkcd --help)
    assert_contains "SYNOPSIS" "$result" "mkcd --help should show usage"
}

test_mkcd_help_short_flag() {
    local result=$(mkcd -h)
    assert_contains "SYNOPSIS" "$result" "mkcd -h should show usage"
}

test_tre_help_flag() {
    local result=$(tre --help)
    assert_contains "SYNOPSIS" "$result" "tre --help should show usage"
}

test_tre_help_short_flag() {
    local result=$(tre -h)
    assert_contains "SYNOPSIS" "$result" "tre -h should show usage"
}

test_up_help_flag() {
    local result=$(up --help)
    assert_contains "SYNOPSIS" "$result" "up --help should show usage"
}

test_up_help_short_flag() {
    local result=$(up -h)
    assert_contains "SYNOPSIS" "$result" "up -h should show usage"
}

log_info "Running navigation function tests"
test_mkcd_help_flag
test_mkcd_help_short_flag
test_tre_help_flag
test_tre_help_short_flag
test_up_help_flag
test_up_help_short_flag
log_info "All navigation function tests passed!"
