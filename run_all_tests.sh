#!/bin/bash

# Run all test scripts
set -euo pipefail

# Source common utilities
source "${DOTFILES}/bash/functions/log_utils.sh"

log_info_test "Running All Tests"
echo

# Find and execute all test scripts
find "${DOTFILES}" -name "*_test.sh" -type f | while read -r test_file; do
    log_info_test "Running: $(basename "$test_file")"
    bash "$test_file"
    echo
done

log_info_test "All Tests Completed"

