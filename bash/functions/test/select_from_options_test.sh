#!/bin/bash

# Import the function to test
source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/interactive/select_from_options.func"
source "${DOTFILES}/bash/functions/test/test_utils.sh"

# Test 1: Help flag shows usage
test_help_flag() {
    local result=$(select_from_options --help)
    local contains_usage=$(echo "$result" | grep -c "SYNOPSIS")
    assert_equals "1" "$contains_usage" "Help flag should show usage information"
}

# Test 2: Invalid option returns error
test_invalid_option() {
    local result=$(select_from_options --invalid 2>&1)
    local contains_error=$(echo "$result" | grep -c "Invalid option")
    assert_equals "1" "$contains_error" "Invalid option should show error message"
}

# Test 3: Default option with single result
test_default_option() {
    # Create test directory with single file
    mkdir -p /tmp/test_select
    touch /tmp/test_select/testfile

    local result=$(select_from_options -d "ls /tmp/test_select")
    assert_equals "testfile" "$result" "Default option should select single result"

    rm -rf /tmp/test_select
}

# Test 4: Quiet mode
test_quiet_mode() {
    mkdir -p /tmp/test_select
    touch /tmp/test_select/testfile

    local result=$(select_from_options -q -d "ls /tmp/test_select")
    local output_lines=$(echo "$result" | wc -l)
    assert_equals "1" "$output_lines" "Quiet mode should have minimal output"

    rm -rf /tmp/test_select
}

# Test 5: No options found
test_no_options() {
    mkdir -p /tmp/test_select
    local result=$(select_from_options "ls /tmp/test_select" 2>&1)
    local contains_error=$(echo "$result" | grep -c "No options found")
    assert_equals "1" "$contains_error" "Should handle no options gracefully"

    rm -rf /tmp/test_select
}

# Test 6: Missing command
test_missing_command() {
    local result=$(select_from_options 2>&1)
    local contains_error=$(echo "$result" | grep -c "Must specify a command")
    assert_equals "1" "$contains_error" "Should require command parameter"
}

# Run all tests
log_info_test "Running select_from_options tests"
test_help_flag
test_invalid_option
test_default_option
test_quiet_mode
test_no_options
test_missing_command
log_info_test "All tests passed!"

