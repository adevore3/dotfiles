#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/test/test_utils.sh"
source "${DOTFILES}/bash/functions/system/bluetooth_connect.func"
source "${DOTFILES}/bash/functions/system/extract.func"
source "${DOTFILES}/bash/functions/system/myip.func"
source "${DOTFILES}/bash/functions/system/modify_partition.func"

test_bluetooth_connect_help_flag() {
    local result=$(bluetooth_connect --help)
    assert_contains "SYNOPSIS" "$result" "bluetooth_connect --help should show usage"
}

test_extract_help_flag() {
    local result=$(extract --help)
    assert_contains "SYNOPSIS" "$result" "extract --help should show usage"
}

test_myip_help_flag() {
    local result=$(myip --help)
    assert_contains "SYNOPSIS" "$result" "myip --help should show usage"
}

test_modify_partition_help_flag() {
    local result=$(modify_partition --help)
    assert_contains "SYNOPSIS" "$result" "modify_partition --help should show usage"
}

log_info "Running system function tests"
test_bluetooth_connect_help_flag
test_extract_help_flag
test_myip_help_flag
test_modify_partition_help_flag
log_info "All system function tests passed!"
