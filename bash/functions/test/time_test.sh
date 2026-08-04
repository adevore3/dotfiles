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

# --- behavior, not just usage text ---
#
# These four all went through GNU-only `date -d` and so produced nothing but a usage dump from BSD date on
# macOS. Asserted in UTC where a zone is involved, so the expectations hold wherever the suite runs.

assert_equals "2023-03-08 06:10:21" "$(from_unixtime -f utc 1678255821)" \
  "from_unixtime -f utc converts an epoch"

assert_equals "20230308" "$(from_unixtime -f date_utc 1678255821)" \
  "from_unixtime -f date_utc converts an epoch"

assert_equals "20230308_061021" "$(from_unixtime -f date_time_utc 1678255821)" \
  "from_unixtime -f date_time_utc converts an epoch"

# Milliseconds get rounded to seconds before formatting; make sure that path still reaches date.
assert_equals "20230308_061021" "$(from_unixtime -f date_time_utc 1678255821000)" \
  "from_unixtime accepts millisecond input"

output=$(from_unixtime 1678255821 2>&1)
assert_contains "2023" "$output" "from_unixtime default format converts an epoch"

assert_equals "1678255821" "$(TZ=UTC from_datetime '2023-03-08T06:10:21')" \
  "from_datetime converts a datetime to an epoch"

assert_equals "1678255821" "$(TZ=UTC from_datetime '2023-03-08T06:10:21.550')" \
  "from_datetime tolerates fractional seconds"

# Exactly one day apart. This used to print 00:00:00, because `date -u +%H:%M:%S` wrapped at 24h.
assert_equals "24:00:00" "$(date_diff '2023-01-02' '2023-01-01' 2>/dev/null | tail -n1)" \
  "date_diff formats a 24h gap without wrapping"

# Order must not matter -- the difference is absolute.
assert_equals "24:00:00" "$(date_diff '2023-01-01' '2023-01-02' 2>/dev/null | tail -n1)" \
  "date_diff is symmetric"

assert_equals "01:30:00" "$(date_diff '2023-01-01 12:00:00' '2023-01-01 10:30:00' 2>/dev/null | tail -n1)" \
  "date_diff formats a sub-day gap"

echo ""
echo "All time function tests passed!"
