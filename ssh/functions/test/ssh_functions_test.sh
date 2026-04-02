#!/bin/bash

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"

echo "=== ssh functions help flag tests ==="

# --- ssh_made_easy ---
source "${DOTFILES}/ssh/functions/ssh_made_easy.func"

output=$(ssh_made_easy -h 2>&1)
assert_contains "ssh_made_easy" "$output" "ssh_made_easy -h contains function name"
assert_contains "SYNOPSIS" "$output" "ssh_made_easy -h contains SYNOPSIS"
assert_contains "--help" "$output" "ssh_made_easy -h contains --help"

output=$(ssh_made_easy --help 2>&1)
assert_contains "ssh_made_easy" "$output" "ssh_made_easy --help contains function name"

echo "=== All ssh functions help flag tests passed ==="
