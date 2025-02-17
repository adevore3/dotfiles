#!/bin/bash

# Run all test scripts
set -uo pipefail

# Source common utilities
source "${DOTFILES}/bash/functions/log_utils.sh"

log_info_test "Running All Tests"
echo

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=()

# Find and execute all test scripts
while read -r test_file; do
    ((total_tests++))
    log_info_test "Running: $(basename "$test_file")"
    if bash "$test_file"; then
        ((passed_tests++))
        echo -e "\033[32m✓ PASS\033[0m: $(basename "$test_file")"
    else
        failed_tests+=("$(basename "$test_file")")
        echo -e "\033[31m✗ FAIL\033[0m: $(basename "$test_file")"
    fi
    echo
done < <(find "${DOTFILES}" -name "*_test.sh" -type f)

# Print summary
echo "----------------------------------------"
log_info_test "Test Summary:"
echo "Total Tests: $total_tests"
echo -e "\033[32mPassed: $passed_tests\033[0m"
echo -e "\033[31mFailed: $((total_tests - passed_tests))\033[0m"

if [ ${#failed_tests[@]} -gt 0 ]; then
    echo -e "\nFailed tests:"
    printf '\033[31m%s\033[0m\n' "${failed_tests[@]}"
    exit 1
fi

log_info_test "All Tests Completed Successfully"
exit 0

