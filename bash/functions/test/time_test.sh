#!/bin/bash

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"

echo "=== Time Function Tests ==="

# --- date_diff ---
source "${DOTFILES}/bash/functions/time/date_diff.func"

output=$(date_diff -h 2>&1)
assert_contains "SYNOPSIS" "$output" "date_diff -h shows SYNOPSIS"

output=$(date_diff --help 2>&1)
assert_contains "date_diff" "$output" "date_diff --help shows function name"

# --- from_datetime ---
source "${DOTFILES}/bash/functions/time/from_datetime.func"

output=$(from_datetime -h 2>&1)
assert_contains "SYNOPSIS" "$output" "from_datetime -h shows SYNOPSIS"

output=$(from_datetime --help 2>&1)
assert_contains "from_datetime" "$output" "from_datetime --help shows function name"

# --- from_unixtime ---
source "${DOTFILES}/bash/functions/time/from_unixtime.func"

output=$(from_unixtime -h 2>&1)
assert_contains "SYNOPSIS" "$output" "from_unixtime -h shows SYNOPSIS"

output=$(from_unixtime --help 2>&1)
assert_contains "from_unixtime" "$output" "from_unixtime --help shows function name"

# --- unixtime ---
source "${DOTFILES}/bash/functions/time/unixtime.func"

output=$(unixtime -h 2>&1)
assert_contains "unixtime" "$output" "unixtime -h shows function name"

output=$(unixtime --help 2>&1)
assert_contains "unixtime" "$output" "unixtime --help shows function name"

echo ""
echo "All time function tests passed!"
