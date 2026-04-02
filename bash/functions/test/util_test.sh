#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/text/join_by.func"
source "${DOTFILES}/bash/functions/util/backup_files.func"
source "${DOTFILES}/bash/functions/util/calculate.func"
source "${DOTFILES}/bash/functions/util/check_variable.func"
source "${DOTFILES}/bash/functions/util/conditionally_prefix_path.func"
source "${DOTFILES}/bash/functions/util/open_in_firefox.func"
source "${DOTFILES}/bash/functions/util/rename_last_screenshot.func"
source "${DOTFILES}/bash/functions/util/teh.func"

test_backup_files_help_flag() {
    local result=$(backup_files --help)
    assert_contains "SYNOPSIS" "$result" "backup_files --help should show usage"
}

test_calculate_help_flag() {
    local result=$(calculate --help)
    assert_contains "SYNOPSIS" "$result" "calculate --help should show usage"
}

test_check_variable_help_flag() {
    local result=$(check_variable --help)
    assert_contains "SYNOPSIS" "$result" "check_variable --help should show usage"
}

test_conditionally_prefix_path_help_flag() {
    local result=$(conditionally_prefix_path --help)
    assert_contains "SYNOPSIS" "$result" "conditionally_prefix_path --help should show usage"
}

test_open_in_firefox_help_flag() {
    local result=$(open_in_firefox --help)
    assert_contains "SYNOPSIS" "$result" "open_in_firefox --help should show usage"
}

test_rename_last_screenshot_help_flag() {
    local result=$(rename_last_screenshot --help)
    assert_contains "SYNOPSIS" "$result" "rename_last_screenshot --help should show usage"
}

test_teh_help_flag() {
    local result=$(teh --help)
    assert_contains "SYNOPSIS" "$result" "teh --help should show usage"
}

log_info "Running util function tests"
test_backup_files_help_flag
test_calculate_help_flag
test_check_variable_help_flag
test_conditionally_prefix_path_help_flag
test_open_in_firefox_help_flag
test_rename_last_screenshot_help_flag
test_teh_help_flag
log_info "All util function tests passed!"
