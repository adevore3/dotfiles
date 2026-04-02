#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/git/functions/git_add_files.func"
source "${DOTFILES}/git/functions/git_checkout_branch.func"
source "${DOTFILES}/git/functions/git_checkout_custom_branch.func"
source "${DOTFILES}/git/functions/git_checkout_most_recent_branch.func"
source "${DOTFILES}/git/functions/git_checkout_most_recent_remote_branch.func"
source "${DOTFILES}/git/functions/git_checkout_remote_branch.func"
source "${DOTFILES}/git/functions/git_cleanup.func"
source "${DOTFILES}/git/functions/git_cleanup_not_merged.func"
source "${DOTFILES}/git/functions/git_default_branch.func"
source "${DOTFILES}/git/functions/git_find_file.func"
source "${DOTFILES}/git/functions/git_info.func"
source "${DOTFILES}/git/functions/git_not_merged.func"
source "${DOTFILES}/git/functions/git_push_set_upstream.func"
source "${DOTFILES}/git/functions/git_rebase_helper.func"
source "${DOTFILES}/git/functions/git_squash_commits.func"
source "${DOTFILES}/git/functions/git_stashapply.func"
source "${DOTFILES}/git/functions/git_stashdrop.func"
source "${DOTFILES}/git/functions/git_stashow.func"
source "${DOTFILES}/git/functions/git_stashowp.func"
source "${DOTFILES}/git/functions/git_stats.func"

test_git_add_files_help_flag() {
    local result=$(git_add_files --help)
    assert_contains "SYNOPSIS" "$result" "git_add_files --help should show usage"
}

test_git_checkout_branch_help_flag() {
    local result=$(git_checkout_branch --help)
    assert_contains "SYNOPSIS" "$result" "git_checkout_branch --help should show usage"
}

test_git_checkout_custom_branch_help_flag() {
    local result=$(git_checkout_custom_branch --help)
    assert_contains "SYNOPSIS" "$result" "git_checkout_custom_branch --help should show usage"
}

test_git_checkout_most_recent_branch_help_flag() {
    local result=$(git_checkout_most_recent_branch --help)
    assert_contains "SYNOPSIS" "$result" "git_checkout_most_recent_branch --help should show usage"
}

test_git_checkout_most_recent_remote_branch_help_flag() {
    local result=$(git_checkout_most_recent_remote_branch --help)
    assert_contains "SYNOPSIS" "$result" "git_checkout_most_recent_remote_branch --help should show usage"
}

test_git_checkout_remote_branch_help_flag() {
    local result=$(git_checkout_remote_branch --help)
    assert_contains "SYNOPSIS" "$result" "git_checkout_remote_branch --help should show usage"
}

test_git_cleanup_help_flag() {
    local result=$(git_cleanup --help)
    assert_contains "SYNOPSIS" "$result" "git_cleanup --help should show usage"
}

test_git_cleanup_not_merged_help_flag() {
    local result=$(git_cleanup_not_merged --help)
    assert_contains "SYNOPSIS" "$result" "git_cleanup_not_merged --help should show usage"
}

test_git_default_branch_help_flag() {
    local result=$(git_default_branch --help)
    assert_contains "SYNOPSIS" "$result" "git_default_branch --help should show usage"
}

test_git_find_file_help_flag() {
    local result=$(git_find_file --help)
    assert_contains "SYNOPSIS" "$result" "git_find_file --help should show usage"
}

test_git_info_help_flag() {
    local result=$(git_info --help)
    assert_contains "SYNOPSIS" "$result" "git_info --help should show usage"
}

test_git_not_merged_help_flag() {
    local result=$(git_not_merged --help)
    assert_contains "SYNOPSIS" "$result" "git_not_merged --help should show usage"
}

test_git_push_set_upstream_help_flag() {
    local result=$(git_push_set_upstream --help)
    assert_contains "SYNOPSIS" "$result" "git_push_set_upstream --help should show usage"
}

test_git_rebase_helper_help_flag() {
    local result=$(git_rebase_helper --help)
    assert_contains "SYNOPSIS" "$result" "git_rebase_helper --help should show usage"
}

test_git_squash_commits_help_flag() {
    local result=$(git_squash_commits --help)
    assert_contains "SYNOPSIS" "$result" "git_squash_commits --help should show usage"
}

test_git_stashapply_help_flag() {
    local result=$(git_stashapply --help)
    assert_contains "SYNOPSIS" "$result" "git_stashapply --help should show usage"
}

test_git_stashdrop_help_flag() {
    local result=$(git_stashdrop --help)
    assert_contains "SYNOPSIS" "$result" "git_stashdrop --help should show usage"
}

test_git_stashow_help_flag() {
    local result=$(git_stashow --help)
    assert_contains "SYNOPSIS" "$result" "git_stashow --help should show usage"
}

test_git_stashowp_help_flag() {
    local result=$(git_stashowp --help)
    assert_contains "SYNOPSIS" "$result" "git_stashowp --help should show usage"
}

test_git_stats_help_flag() {
    local result=$(git_stats --help)
    assert_contains "SYNOPSIS" "$result" "git_stats --help should show usage"
}

# Also test -h flag for a few functions
test_git_add_files_h_flag() {
    local result=$(git_add_files -h)
    assert_contains "SYNOPSIS" "$result" "git_add_files -h should show usage"
}

test_git_cleanup_h_flag() {
    local result=$(git_cleanup -h)
    assert_contains "SYNOPSIS" "$result" "git_cleanup -h should show usage"
}

test_git_cleanup_not_merged_h_flag() {
    local result=$(git_cleanup_not_merged -h)
    assert_contains "SYNOPSIS" "$result" "git_cleanup_not_merged -h should show usage"
}

# Run all tests
test_git_add_files_help_flag
test_git_checkout_branch_help_flag
test_git_checkout_custom_branch_help_flag
test_git_checkout_most_recent_branch_help_flag
test_git_checkout_most_recent_remote_branch_help_flag
test_git_checkout_remote_branch_help_flag
test_git_cleanup_help_flag
test_git_cleanup_not_merged_help_flag
test_git_default_branch_help_flag
test_git_find_file_help_flag
test_git_info_help_flag
test_git_not_merged_help_flag
test_git_push_set_upstream_help_flag
test_git_rebase_helper_help_flag
test_git_squash_commits_help_flag
test_git_stashapply_help_flag
test_git_stashdrop_help_flag
test_git_stashow_help_flag
test_git_stashowp_help_flag
test_git_stats_help_flag
test_git_add_files_h_flag
test_git_cleanup_h_flag
test_git_cleanup_not_merged_h_flag

echo ""
echo "All git function help flag tests passed!"
