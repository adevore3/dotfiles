#!/bin/bash

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"

echo "=== node functions help flag tests ==="

# --- cdnvm ---
source "${DOTFILES}/node/functions/cdnvm.func"

output=$(cdnvm -h 2>&1)
assert_contains "cdnvm" "$output" "cdnvm -h contains function name"
assert_contains "SYNOPSIS" "$output" "cdnvm -h contains SYNOPSIS"
assert_contains "--help" "$output" "cdnvm -h contains --help"

output=$(cdnvm --help 2>&1)
assert_contains "cdnvm" "$output" "cdnvm --help contains function name"

# --- execute_node_scripts_grep ---
source "${DOTFILES}/node/functions/execute_node_scripts_grep.func"

output=$(execute_node_scripts_grep -h 2>&1)
assert_contains "execute_node_scripts_grep" "$output" "execute_node_scripts_grep -h contains function name"
assert_contains "SYNOPSIS" "$output" "execute_node_scripts_grep -h contains SYNOPSIS"
assert_contains "--help" "$output" "execute_node_scripts_grep -h contains --help"

output=$(execute_node_scripts_grep --help 2>&1)
assert_contains "execute_node_scripts_grep" "$output" "execute_node_scripts_grep --help contains function name"

echo "=== All node functions help flag tests passed ==="
