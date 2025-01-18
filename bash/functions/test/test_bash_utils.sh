#!/bin/bash

# Ensure script fails on any error
set -e

# Source the utils file
if [ ! -f "../bash_utils.sh" ]; then
    if [ ! -f "./bash_utils.sh" ]; then
        echo "bash_utils.sh not found in current or parent directory" >&2
        exit 1
    fi
    source ./bash_utils.sh
else
    source ../bash_utils.sh
fi

# Test helper function
test_header() {
    echo -e "\n=== $1 ==="
}

# Test logging at different levels
test_header "Testing log levels"

echo "Testing LOG_LEVEL=1 (DEBUG)"
LOG_LEVEL=1
log_debug "This debug message should show"
log_info "This info message should show"
log_warn "This warn message should show"
log_error "This error message should show"

echo -e "\nTesting LOG_LEVEL=2 (INFO)"
LOG_LEVEL=2
log_debug "This debug message should NOT show"
log_info "This info message should show"
log_warn "This warn message should show"
log_error "This error message should show"

echo -e "\nTesting LOG_LEVEL=3 (WARN)"
LOG_LEVEL=3
log_debug "This debug message should NOT show"
log_info "This info message should NOT show"
log_warn "This warn message should show"
log_error "This error message should show"

echo -e "\nTesting LOG_LEVEL=4 (ERROR)"
LOG_LEVEL=4
log_debug "This debug message should NOT show"
log_info "This info message should NOT show"
log_warn "This warn message should NOT show"
log_error "This error message should show"

# Test parameter validation
test_header "Testing parameter validation"

echo "Testing empty messages"
LOG_LEVEL=1  # Set to debug to see all validation errors
log_debug "" || echo "Debug validation passed"
log_info "" || echo "Info validation passed"
log_warn "" || echo "Warn validation passed"
log_error "" || echo "Error validation passed"

echo -e "\nTesting messages with special characters"
log_debug "Debug message with *special* [characters]"
log_info "Info message with \"quotes\" and 'apostrophes'"
log_warn "Warn message with \$variables and #hash"
log_error "Error message with newline\nand tab\t characters"

echo -e "\nTesting invalid LOG_LEVEL values"
LOG_LEVEL=0
log_error "This should still show with LOG_LEVEL=0"
LOG_LEVEL=5
log_error "This should still show with LOG_LEVEL=5"
LOG_LEVEL="invalid"
LOG_LEVEL="invalid"
log_error "This should still show with invalid LOG_LEVEL"

# Test set_log_level function
test_header "Testing set_log_level function"

echo "Testing valid log levels"
set_log_level 1 && echo "Set to DEBUG (1) passed"
log_debug "This debug message should show"
log_info "This info message should show"

set_log_level 2 && echo "Set to INFO (2) passed"
log_debug "This debug message should NOT show"
log_info "This info message should show"

set_log_level 3 && echo "Set to WARN (3) passed"
log_info "This info message should NOT show"
log_warn "This warn message should show"

set_log_level 4 && echo "Set to ERROR (4) passed"
log_warn "This warn message should NOT show"
log_error "This error message should show"

echo -e "\nTesting invalid log levels"
set_log_level 0 || echo "Rejected level 0 (passed)"
set_log_level 5 || echo "Rejected level 5 (passed)"
set_log_level abc || echo "Rejected non-numeric (passed)"
set_log_level "" || echo "Rejected empty string (passed)"

# Test log level helper functions
test_header "Testing log level helper functions"

echo "Testing set_log_level_debug()"
set_log_level_debug
log_debug "This debug message should show"
log_info "This info message should show"
log_warn "This warn message should show"
log_error "This error message should show"

echo -e "\nTesting set_log_level_info()"
set_log_level_info
log_debug "This debug message should NOT show"
log_info "This info message should show"
log_warn "This warn message should show"
log_error "This error message should show"

echo -e "\nTesting set_log_level_warn()"
set_log_level_warn
log_debug "This debug message should NOT show"
log_info "This info message should NOT show"
log_warn "This warn message should show"
log_error "This error message should show"

echo -e "\nTesting set_log_level_error()"
set_log_level_error
log_debug "This debug message should NOT show"
log_info "This info message should NOT show"
log_warn "This warn message should NOT show"
log_error "This error message should show"

test_header "All tests completed"
