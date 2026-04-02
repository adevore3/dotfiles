#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/text/highlight.func"
source "${DOTFILES}/bash/functions/text/join_by.func"
source "${DOTFILES}/bash/functions/text/trim.func"
source "${DOTFILES}/bash/functions/text/urlencode.func"

test_highlight_help_flag() {
    local result=$(highlight --help)
    assert_contains "SYNOPSIS" "$result" "highlight --help should show usage"
}

test_join_by_help_flag() {
    local result=$(join_by --help)
    assert_contains "SYNOPSIS" "$result" "join_by --help should show usage"
}

test_trim_help_flag() {
    local result=$(trim --help)
    assert_contains "SYNOPSIS" "$result" "trim --help should show usage"
}

test_urlencode_help_flag() {
    local result=$(urlencode --help)
    assert_contains "SYNOPSIS" "$result" "urlencode --help should show usage"
}

log_info "Running text function tests"
test_highlight_help_flag
test_join_by_help_flag
test_trim_help_flag
test_urlencode_help_flag
log_info "All text function tests passed!"
