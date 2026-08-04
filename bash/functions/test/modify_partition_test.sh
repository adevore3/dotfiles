#!/usr/bin/env bash

# Drives the real modify_partition against a throwaway run.sh, on whatever date/sed this host ships. The expected
# values are literals rather than a second computation, so the same assertions have to hold on GNU and on BSD --
# they were taken from the pre-port GNU-only implementation, which this reproduced across a 96-case matrix of
# year/month/day/hour x increase/decrease x 1/3/10/24 on three base dates.
#
# Deliberately away from month-end: from day 29 onward GNU normalizes a month forward while BSD clamps, and that
# divergence is documented in platform_utils.sh rather than asserted here.

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/system/modify_partition.func"

echo "=== modify_partition Tests ==="

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Rebuild the fixture before each case, since modify_partition edits in place.
function write_fixture() {
  cat > "${work_dir}/${1:-run.sh}" <<'EOF'
#!/bin/bash
start="2026-01-01T00:00:00-06:00"
end="2026-02-01T00:00:00-06:00"
EOF
}

function field() {
  sed -n "s/^${2}=\"\(.*\)\"$/\1/p" "${work_dir}/${1}"
}

# --- the four partitions ---

write_fixture
(cd "$work_dir" && modify_partition -m > /dev/null 2>&1)
assert_equals "2026-02-01T00:00:00-06:00" "$(field run.sh start)" "-m increments start's month by 1"
assert_equals "2026-03-01T00:00:00-06:00" "$(field run.sh end)" "-m increments end's month by 1"

write_fixture
(cd "$work_dir" && modify_partition -y --increase 2 > /dev/null 2>&1)
assert_equals "2028-01-01T00:00:00-06:00" "$(field run.sh start)" "-y --increase 2 adds two years to start"
assert_equals "2028-02-01T00:00:00-06:00" "$(field run.sh end)" "-y --increase 2 adds two years to end"

write_fixture
(cd "$work_dir" && modify_partition -d --decrease 3 > /dev/null 2>&1)
assert_equals "2025-12-29T00:00:00-06:00" "$(field run.sh start)" "-d --decrease 3 subtracts days across a year boundary"
assert_equals "2026-01-29T00:00:00-06:00" "$(field run.sh end)" "-d --decrease 3 subtracts three days from end"

write_fixture
(cd "$work_dir" && modify_partition -hh --increase 24 > /dev/null 2>&1)
assert_equals "2026-01-02T00:00:00-06:00" "$(field run.sh start)" "-hh --increase 24 rolls start over a day"
assert_equals "2026-02-02T00:00:00-06:00" "$(field run.sh end)" "-hh --increase 24 rolls end over a day"

# The offset has to survive untouched. It is what makes the shift unambiguous, and BSD's %z drops the colon.
write_fixture
(cd "$work_dir" && modify_partition -m > /dev/null 2>&1)
assert_contains "-06:00" "$(field run.sh start)" "the trailing UTC offset keeps its colon form"

# --- -f, since the default is run.sh ---

write_fixture run_custom.sh
(cd "$work_dir" && modify_partition -m -f run_custom.sh > /dev/null 2>&1)
assert_equals "2026-02-01T00:00:00-06:00" "$(field run_custom.sh start)" "-f edits the named file"

# --- the guards ---

# Regression: with no partition flag there was no unit to shift by, so date failed, $new_date came out empty, and
# GNU sed wrote that empty string over the real date. Running this with no flag deleted both dates.
write_fixture
output=$( (cd "$work_dir" && modify_partition 2>&1) )
assert_contains "no partition selected" "$output" "no partition flag is rejected"
assert_equals "2026-01-01T00:00:00-06:00" "$(field run.sh start)" "a rejected run leaves start untouched"
assert_equals "2026-02-01T00:00:00-06:00" "$(field run.sh end)" "a rejected run leaves end untouched"

output=$( (cd "$work_dir" && modify_partition -m -f nope.sh 2>&1) )
assert_contains "to exist" "$output" "a missing file is reported"

output=$( (cd "$work_dir" && modify_partition --bogus 2>&1) )
assert_contains "Invalid option" "$output" "an unknown option is reported"

output=$(modify_partition -h)
assert_contains "modify_partition" "$output" "-h prints usage"

# A file with no start=/end= must be reported, not silently rewritten.
printf '#!/bin/bash\necho hi\n' > "${work_dir}/bare.sh"
output=$( (cd "$work_dir" && modify_partition -m -f bare.sh 2>&1) )
assert_contains "Could not find" "$output" "a file with no start=/end= is reported"
assert_equals "#!/bin/bash" "$(head -1 "${work_dir}/bare.sh")" "a file with no dates is left alone"

echo ""
echo "All modify_partition tests passed!"
