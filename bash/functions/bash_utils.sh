#!/bin/bash

# Check if a command exists in the system PATH
#
# Arguments:
#   $1 - Command name to check
#   $2 - Optional custom message to display after the error
#
# Returns:
#   0 - Command exists
#   1 - Command not found
#
# Examples:
#   check_command_exists git "Please install git to continue"
#   check_command_exists aws "AWS CLI v2 is required - see docs at https://example.com"
#   check_command_exists docker
function check_command_exists() {
  local command=$1
  local message=${2:-""}

  if [ ! -x "$(command -v $command)" ]; then
    echo "ERROR '$command' not found"
    [ ! -z "$message" ] && echo "$message"
    return 1
  fi
  return 0
}

# Check if the tokentamer command exists
function check_command_tokentamer_exists() {
  check_command_exists tokentamer "Follow steps to install at https://wiki.indeed.com/x/D4xiF"
}

# Export functions
export -f check_command_exists
export -f check_command_tokentamer_exists
