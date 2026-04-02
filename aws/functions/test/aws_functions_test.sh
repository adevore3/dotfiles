#!/bin/bash

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"

echo "=== aws functions help flag tests ==="

# --- aws_ssm (already has help) ---
source "${DOTFILES}/aws/functions/aws_ssm.func" 2>/dev/null || true

output=$(aws_ssm -h 2>&1)
assert_contains "aws_ssm" "$output" "aws_ssm -h contains function name"
assert_contains "SYNOPSIS" "$output" "aws_ssm -h contains SYNOPSIS"
assert_contains "--help" "$output" "aws_ssm -h contains --help"

output=$(aws_ssm --help 2>&1)
assert_contains "aws_ssm" "$output" "aws_ssm --help contains function name"

# --- aws_copy_profile ---
source "${DOTFILES}/aws/functions/aws_copy_profile.func"

output=$(aws_copy_profile -h 2>&1)
assert_contains "aws_copy_profile" "$output" "aws_copy_profile -h contains function name"
assert_contains "SYNOPSIS" "$output" "aws_copy_profile -h contains SYNOPSIS"
assert_contains "--help" "$output" "aws_copy_profile -h contains --help"

output=$(aws_copy_profile --help 2>&1)
assert_contains "aws_copy_profile" "$output" "aws_copy_profile --help contains function name"

echo "=== All aws functions help flag tests passed ==="
