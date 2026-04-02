#!/bin/bash

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/io/cap.func"
source "${DOTFILES}/bash/functions/text/join_by.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_clipboard.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_tmux_clipboard.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_all_clipboards.func"
source "${DOTFILES}/bash/functions/interactive/select_from_options.func"
source "${DOTFILES}/bash/functions/interactive/select_from_last_command.func"
source "${DOTFILES}/bash/functions/interactive/alias_grep_execute.func"

echo "=== Interactive Function Help Flag Tests ==="

# alias_grep_execute -h
output=$(alias_grep_execute -h 2>&1)
assert_contains "NAME:" "$output" "alias_grep_execute -h prints NAME section"
assert_contains "alias_grep_execute" "$output" "alias_grep_execute -h prints function name"
assert_contains "SYNOPSIS" "$output" "alias_grep_execute -h prints SYNOPSIS section"
assert_contains "--help" "$output" "alias_grep_execute -h documents --help option"

output=$(alias_grep_execute --help 2>&1)
assert_contains "NAME:" "$output" "alias_grep_execute --help prints NAME section"

# select_from_options -h
output=$(select_from_options -h 2>&1)
assert_contains "select_from_options" "$output" "select_from_options -h prints usage with function name"
assert_contains "help" "$output" "select_from_options -h mentions help"

output=$(select_from_options --help 2>&1)
assert_contains "select_from_options" "$output" "select_from_options --help prints usage with function name"

# select_from_last_command -h
output=$(select_from_last_command -h 2>&1)
assert_contains "select_from_last_command" "$output" "select_from_last_command -h prints usage with function name"
assert_contains "help" "$output" "select_from_last_command -h mentions help"

output=$(select_from_last_command --help 2>&1)
assert_contains "select_from_last_command" "$output" "select_from_last_command --help prints usage with function name"

echo
echo "All interactive help flag tests passed!"
