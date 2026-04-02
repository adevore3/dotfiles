#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/development/awkp.func"
source "${DOTFILES}/bash/functions/development/open_scratch.func"
source "${DOTFILES}/bash/functions/development/recursive_type.func"
source "${DOTFILES}/bash/functions/development/source_dotfiles_file.func"
source "${DOTFILES}/bash/functions/development/source_dotfiles_most_recent_file.func"
source "${DOTFILES}/bash/functions/development/standup.func"

test_awkp_help_flag() {
    local result=$(awkp --help)
    assert_contains "SYNOPSIS" "$result" "awkp --help should show usage"
}

test_open_scratch_help_flag() {
    local result=$(open_scratch --help)
    assert_contains "SYNOPSIS" "$result" "open_scratch --help should show usage"
}

test_recursive_type_help_flag() {
    local result=$(recursive_type --help)
    assert_contains "SYNOPSIS" "$result" "recursive_type --help should show usage"
}

test_source_dotfiles_file_help_flag() {
    local result=$(source_dotfiles_file --help)
    assert_contains "SYNOPSIS" "$result" "source_dotfiles_file --help should show usage"
}

test_source_dotfiles_most_recent_file_help_flag() {
    local result=$(source_dotfiles_most_recent_file --help)
    assert_contains "SYNOPSIS" "$result" "source_dotfiles_most_recent_file --help should show usage"
}

test_standup_help_flag() {
    local result=$(standup --help)
    assert_contains "SYNOPSIS" "$result" "standup --help should show usage"
}

log_info "Running development function tests"
test_awkp_help_flag
test_open_scratch_help_flag
test_recursive_type_help_flag
test_source_dotfiles_file_help_flag
test_source_dotfiles_most_recent_file_help_flag
test_standup_help_flag
log_info "All development function tests passed!"
