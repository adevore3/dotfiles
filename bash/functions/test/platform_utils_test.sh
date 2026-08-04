#!/usr/bin/env bash

# Exercises the platform wrappers against whatever `date`/`sed`/`stat` this host actually ships, so the same
# assertions have to hold on GNU coreutils and on BSD/macOS. Every case here corresponds to a spelling that
# used to be GNU-only somewhere in the repo.

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/platform_utils.sh"

echo "=== Platform Utils Tests ==="

# --- date_from_epoch ---

# 1678255821 == 2023-03-08 06:10:21 UTC. Asserted in UTC so the result does not depend on the host's zone.
assert_equals "2023-03-08 06:10:21" "$(date_from_epoch -u 1678255821 '%Y-%m-%d %H:%M:%S')" \
  "date_from_epoch -u formats an epoch in UTC"

assert_equals "20230308" "$(date_from_epoch -u 1678255821 '%Y%m%d')" \
  "date_from_epoch -u honors a custom format"

assert_equals "20230308_061021" "$(date_from_epoch -u '@1678255821' '%Y%m%d_%H%M%S')" \
  "date_from_epoch tolerates the GNU @-prefixed epoch"

# No format at all still has to produce something, since from_unixtime's "default" mode relies on it.
output=$(date_from_epoch 1678255821)
assert_contains "2023" "$output" "date_from_epoch with no format uses date's default output"

output=$(date_from_epoch 2>&1)
assert_contains "no epoch given" "$output" "date_from_epoch errors when given no epoch"

# --- epoch_from_datetime ---

assert_equals "1678255821" "$(TZ=UTC epoch_from_datetime '2023-03-08T06:10:21')" \
  "epoch_from_datetime parses an ISO datetime"

assert_equals "1678255821" "$(TZ=UTC epoch_from_datetime '2023-03-08 06:10:21')" \
  "epoch_from_datetime parses a space-separated datetime"

# Fractional seconds and a trailing Z are what Claude's transcripts emit; both must be tolerated.
assert_equals "1678255821" "$(TZ=UTC epoch_from_datetime '2023-03-08T06:10:21.550Z')" \
  "epoch_from_datetime drops fractional seconds and a trailing Z"

# A date with no time must land on midnight, not on the current time-of-day -- BSD date's default.
assert_equals "1678233600" "$(TZ=UTC epoch_from_datetime '2023-03-08')" \
  "epoch_from_datetime pads a bare date to midnight"

assert_equals "1678233600" "$(TZ=UTC epoch_from_datetime '20230308')" \
  "epoch_from_datetime parses a compact bare date"

assert_equals "1678255821" "$(epoch_from_datetime 1678255821)" \
  "epoch_from_datetime passes a bare epoch through unchanged"

output=$(epoch_from_datetime 'not a date' 2>&1)
assert_contains "could not parse" "$output" "epoch_from_datetime errors on an unparseable string"

# --- epoch_from_datetime: trailing UTC offsets ---
#
# 2026-01-01T00:00:00-06:00 == 1767247200. The point of these is zone independence: an honored offset pins the
# instant, so the answer must not move with TZ. BSD used to accept the format that consumes only the prefix,
# silently drop the offset, and return a *local-zone* epoch -- 1767225600 under UTC, 1767254400 under Pacific --
# while GNU returned 1767247200 everywhere.
for tz in UTC America/Chicago America/Los_Angeles; do
  assert_equals "1767247200" "$(TZ=$tz epoch_from_datetime '2026-01-01T00:00:00-06:00')" \
    "epoch_from_datetime honors a ±HH:MM offset under TZ=$tz"
done

# BSD's %z accepts only the colonless spelling; both must reach the same instant.
assert_equals "1767247200" "$(TZ=UTC epoch_from_datetime '2026-01-01T00:00:00-0600')" \
  "epoch_from_datetime honors a ±HHMM offset"

assert_equals "$(TZ=UTC epoch_from_datetime '2026-01-01T00:00:00-06:00')" \
  "$(TZ=UTC epoch_from_datetime '2026-01-01T00:00:00-0600')" \
  "epoch_from_datetime treats both offset spellings identically"

# Z is just +0000, and must also be zone-independent rather than parsed as local time.
for tz in UTC America/Los_Angeles; do
  assert_equals "1767225600" "$(TZ=$tz epoch_from_datetime '2026-01-01T00:00:00Z')" \
    "epoch_from_datetime treats Z as +0000 under TZ=$tz"
done

# Fractional seconds *and* an offset together: stripping at the first dot must not eat the offset.
assert_equals "1767247200" "$(TZ=America/Los_Angeles epoch_from_datetime '2026-01-01T00:00:00.550-06:00')" \
  "epoch_from_datetime keeps the offset when dropping fractional seconds"

# Partial matches must be refused outright. BSD prints a warning, an epoch for the prefix, and exits 0.
output=$(TZ=UTC epoch_from_datetime '2026-01-01T00:00:00GARBAGE' 2>&1)
assert_contains "could not parse" "$output" "epoch_from_datetime rejects trailing garbage rather than ignoring it"

# --- utc_offset_colon ---

assert_equals "$(TZ=UTC date +%z | sed -E 's/(...)(..)/\1:\2/')" "$(TZ=UTC utc_offset_colon)" \
  "utc_offset_colon matches %z with a colon inserted"

assert_equals "+00:00" "$(TZ=UTC utc_offset_colon)" "utc_offset_colon renders UTC as +00:00"

# A fixed epoch in a fixed zone, so the sign and both halves are pinned. 2026-01-01 is winter, i.e. CST.
assert_equals "-06:00" "$(TZ=America/Chicago utc_offset_colon 1767247200)" \
  "utc_offset_colon renders a negative offset for a given epoch"

assert_equals "+05:30" "$(TZ=Asia/Kolkata utc_offset_colon 1767247200)" \
  "utc_offset_colon renders a half-hour offset"

# --- round trip ---

# The pairing these two get used in throughout bash/functions/time/, so verify it closes.
epoch=$(TZ=UTC epoch_from_datetime '2023-03-08T06:10:21')
assert_equals "2023-03-08T06:10:21" "$(date_from_epoch -u "$epoch" '%Y-%m-%dT%H:%M:%S')" \
  "epoch_from_datetime and date_from_epoch round trip"

# --- file_mtime_epoch ---

tmp_file=$(mktemp)
mtime=$(file_mtime_epoch "$tmp_file")
assert_equals "yes" "$([[ "$mtime" =~ ^[0-9]+$ ]] && echo yes || echo no)" \
  "file_mtime_epoch returns a bare integer epoch"

# ret's cache-expiry math subtracts this from `date +%s`, so the two have to share an epoch base.
now=$(date +%s)
assert_equals "yes" "$([[ $((now - mtime)) -ge 0 && $((now - mtime)) -lt 60 ]] && echo yes || echo no)" \
  "file_mtime_epoch is on the same epoch base as date +%s"

output=$(file_mtime_epoch 2>&1)
assert_contains "no file given" "$output" "file_mtime_epoch errors when given no file"

# --- sed_in_place ---

echo "hello world" > "$tmp_file"
sed_in_place 's/hello/goodbye/' "$tmp_file"
assert_equals "goodbye world" "$(cat "$tmp_file")" "sed_in_place edits the file in place"

# BSD sed leaves a backup file behind unless -i gets an empty argument; make sure none appeared.
assert_equals "0" "$(find "$(dirname "$tmp_file")" -maxdepth 1 -name "$(basename "$tmp_file")?*" | wc -l | tr -d '[:space:]')" \
  "sed_in_place leaves no backup file"

# -E, since GNU's -r is not portable: this pattern needs extended regex to work at all.
printf 'aaa123bbb\n' > "$tmp_file"
sed_in_place 's/[0-9]{3}/X/' "$tmp_file"
assert_equals "aaaXbbb" "$(cat "$tmp_file")" "sed_in_place applies extended regex without -r"

output=$(sed_in_place 's/a/b/' 2>&1)
assert_contains "usage:" "$output" "sed_in_place errors when given no file"

rm -f "$tmp_file"

# --- date_shift ---

# Fixed in UTC so a host's zone (and any DST boundary in it) cannot move the result. Deliberately away from the
# end of a month: GNU normalizes 01-31 +1 month into March while BSD clamps to February, and that divergence is
# documented rather than asserted.
assert_equals "2026-02-01T00:00:00" "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1 month' '%Y-%m-%dT%H:%M:%S')" \
  "date_shift adds a month"

assert_equals "2027-01-01T00:00:00" "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1 year' '%Y-%m-%dT%H:%M:%S')" \
  "date_shift adds a year"

assert_equals "2025-12-29T00:00:00" "$(TZ=UTC date_shift '2026-01-01T00:00:00' '-3 days' '%Y-%m-%dT%H:%M:%S')" \
  "date_shift subtracts days across a year boundary"

# Regression: handed GNU as a signed count, "-1 month" is read as a -01:00 timezone offset and then *adds* a
# month, landing in February with no error at all. The direction has to be asserted, not assumed.
assert_equals "2025-12-01T00:00:00" "$(TZ=UTC date_shift '2026-01-01T00:00:00' '-1 month' '%Y-%m-%dT%H:%M:%S')" \
  "date_shift subtracts a month rather than reading the sign as a UTC offset"

assert_equals "2026-01-01T02:30:00" "$(TZ=UTC date_shift '2026-01-01T00:30:00' '+2 hours' '%Y-%m-%dT%H:%M:%S')" \
  "date_shift adds hours"

# `m` is month and `M` is minute on BSD; make sure the mapping did not transpose them.
assert_equals "2026-01-01T00:05:00" "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+5 minutes' '%Y-%m-%dT%H:%M:%S')" \
  "date_shift adds minutes, not months"

# Singular, plural and abbreviated spellings all have to reach the same unit.
assert_equals "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1 day' '%F')" \
  "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1 days' '%F')" \
  "date_shift accepts a plural unit"
assert_equals "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1 day' '%F')" \
  "$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1d' '%F')" \
  "date_shift accepts an abbreviated unit with no space"

output=$(TZ=UTC date_shift '2026-01-01T00:00:00' '+1 day')
assert_contains "2026" "$output" "date_shift with no format uses date's default output"

output=$(date_shift 2>&1)
assert_contains "usage:" "$output" "date_shift errors when given no arguments"

output=$(date_shift '2026-01-01T00:00:00' 2>&1)
assert_contains "usage:" "$output" "date_shift errors when given no adjustment"

output=$(date_shift '2026-01-01T00:00:00' 'tomorrow' 2>&1)
assert_contains "cannot parse adjustment" "$output" "date_shift rejects an unparseable adjustment"

output=$(date_shift '2026-01-01T00:00:00' '+1 fortnight' 2>&1)
assert_contains "unknown unit" "$output" "date_shift rejects an unknown unit"

# --- open_target ---

output=$(open_target 2>&1)
assert_contains "no target given" "$output" "open_target errors when given no target"

echo ""
echo "All platform utils tests passed!"
