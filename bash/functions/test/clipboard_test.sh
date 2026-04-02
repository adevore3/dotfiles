#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/clipboard/save_to_clipboard.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_tmux_clipboard.func"
source "${DOTFILES}/bash/functions/clipboard/save_to_all_clipboards.func"

test_save_to_clipboard_help_flag() {
    local result=$(save_to_clipboard --help)
    assert_contains "SYNOPSIS" "$result" "save_to_clipboard --help should show usage"
}

test_save_to_tmux_clipboard_help_flag() {
    # Set TMUX vars to bypass the early tmux session check
    local TMUX="fake" TMUX_PANE="fake"
    local result=$(save_to_tmux_clipboard --help)
    assert_contains "SYNOPSIS" "$result" "save_to_tmux_clipboard --help should show usage"
}

test_save_to_all_clipboards_help_flag() {
    local result=$(save_to_all_clipboards --help)
    assert_contains "SYNOPSIS" "$result" "save_to_all_clipboards --help should show usage"
}

test_save_to_clipboard_help_flag
test_save_to_tmux_clipboard_help_flag
test_save_to_all_clipboards_help_flag

echo "All clipboard tests passed!"
