#!/bin/bash

source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/log_utils.sh"

echo "=== tmux functions help flag tests ==="

# --- create_window_with_n_panes ---
source "${DOTFILES}/tmux/functions/create_window_with_n_panes.func"

output=$(create_window_with_n_panes -h 2>&1)
assert_contains "create_window_with_n_panes" "$output" "create_window_with_n_panes -h contains function name"
assert_contains "SYNOPSIS" "$output" "create_window_with_n_panes -h contains SYNOPSIS"
assert_contains "--help" "$output" "create_window_with_n_panes -h contains --help"

output=$(create_window_with_n_panes --help 2>&1)
assert_contains "create_window_with_n_panes" "$output" "create_window_with_n_panes --help contains function name"

# --- tmux_send_command_every_session_window_pane ---
source "${DOTFILES}/tmux/functions/tmux_send_command_every_session_window_pane.func"

output=$(tmux_send_command_every_session_window_pane -h 2>&1)
assert_contains "tmux_send_command_every_session_window_pane" "$output" "tmux_send_command_every_session_window_pane -h contains function name"
assert_contains "SYNOPSIS" "$output" "tmux_send_command_every_session_window_pane -h contains SYNOPSIS"
assert_contains "--help" "$output" "tmux_send_command_every_session_window_pane -h contains --help"

output=$(tmux_send_command_every_session_window_pane --help 2>&1)
assert_contains "tmux_send_command_every_session_window_pane" "$output" "tmux_send_command_every_session_window_pane --help contains function name"

echo "=== All tmux functions help flag tests passed ==="
