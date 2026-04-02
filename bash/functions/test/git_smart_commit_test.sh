#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/git/git_smart_commit_message.func"

test_git_smart_commit_message_help_flag() {
    local result=$(git_smart_commit_message --help)
    assert_contains "SYNOPSIS" "$result" "git_smart_commit_message --help should show usage"
}

test_git_smart_commit_message_help_flag

echo "All git_smart_commit tests passed!"
