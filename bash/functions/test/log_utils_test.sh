#!/bin/bash

# Test suite for log_utils.sh
set -euo pipefail

# Source the required files
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"

# Test functions
test_log_level_setting() {
    echo "[INFO] === Testing log level setting ==="

    set_log_level 1
    assert_equals "1" "$LOG_LEVEL" "Setting log level to DEBUG (1)"

    set_log_level 2
    assert_equals "2" "$LOG_LEVEL" "Setting log level to INFO (2)"

    set_log_level 3
    assert_equals "3" "$LOG_LEVEL" "Setting log level to WARN (3)"

    set_log_level 4
    assert_equals "4" "$LOG_LEVEL" "Setting log level to ERROR (4)"

    # Test invalid log level
    local error_output
    error_output=$(set_log_level 5 2>&1 || true)
    assert_contains "[ERROR] Log level must be between 1 and 4" "$error_output" "Invalid log level should show error"
}

test_log_formatting() {
    echo "[INFO] === Testing log message formatting ==="

    local output

    # Test DEBUG format
    set_log_level 1
    output=$(log_debug "test message")
    assert_contains "[DEBUG]" "$output" "Debug message should have [DEBUG] prefix"
    assert_contains "test message" "$output" "Debug message should contain the message"

    # Test INFO format
    output=$(log_info "test message")
    assert_contains "[INFO]" "$output" "Info message should have [INFO] prefix"
    assert_contains "test message" "$output" "Info message should contain the message"

    # Test WARN format
    output=$(log_warn "test message" 2>&1)
    assert_contains "[WARN]" "$output" "Warn message should have [WARN] prefix"
    assert_contains "test message" "$output" "Warn message should contain the message"

    # Test ERROR format
    output=$(log_error "test message" 2>&1)
    assert_contains "[ERROR]" "$output" "Error message should have [ERROR] prefix"
    assert_contains "test message" "$output" "Error message should contain the message"
}

test_log_level_filtering() {
    echo "[INFO] === Testing log level filtering ==="

    # Test INFO level (should hide debug)
    set_log_level 2
    local output
    output=$(log_debug "debug msg")
    assert_equals "" "$output" "INFO level should hide debug messages"

    output=$(log_info "info msg")
    assert_contains "info msg" "$output" "INFO level should show info messages"

    # Test ERROR level (should only show errors)
    set_log_level 4
    output=$(log_warn "warn msg" 2>&1)
    assert_equals "" "$output" "ERROR level should hide warn messages"

    output=$(log_error "error msg" 2>&1)
    assert_contains "error msg" "$output" "ERROR level should show error messages"
}

test_helper_functions() {
    echo "[INFO] === Testing helper functions ==="

    set_log_level_debug
    assert_equals "1" "$LOG_LEVEL" "set_log_level_debug should set level to 1"

    set_log_level_info
    assert_equals "2" "$LOG_LEVEL" "set_log_level_info should set level to 2"

    set_log_level_warn
    assert_equals "3" "$LOG_LEVEL" "set_log_level_warn should set level to 3"

    set_log_level_error
    assert_equals "4" "$LOG_LEVEL" "set_log_level_error should set level to 4"
}

# Run all tests
run_tests() {
    log_info "=== Running log_utils.sh tests ==="
    echo

    test_log_level_setting
    echo
    test_log_formatting
    echo
    test_log_level_filtering
    echo
    test_helper_functions
    echo

    log_info "All tests completed successfully!"
}

# Execute tests
run_tests

