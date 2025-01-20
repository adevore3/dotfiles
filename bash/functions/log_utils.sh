#!/bin/bash

# Utility functions for bash scripts
# Contains logging helpers with different severity levels
#
# Log Levels:
#   1 (DEBUG) - Detailed debug information
#   2 (INFO)  - General information messages (default)
#   3 (WARN)  - Warning messages
#   4 (ERROR) - Error messages

# Log level constants
declare -p DEBUG &>/dev/null || declare -r DEBUG=1
declare -p INFO &>/dev/null || declare -r INFO=2
declare -p WARN &>/dev/null || declare -r WARN=3
declare -p ERROR &>/dev/null || declare -r ERROR=4

# Global variables
declare LOG_LEVEL=${LOG_LEVEL:-2}  # Default to INFO level

# Print informational message
# Arguments:
#   $1 - Message to print
log_info() {
    local message="$1"
    if [[ -z "$message" ]]; then
        log_error "log_info requires a message parameter" >&2
        return 1
    fi

    if [[ $LOG_LEVEL -le $INFO ]]; then
        echo "[INFO] $message"
    fi
}

# Print informational message for unit tests
# Arguments:
#   $1 - Message to print
log_info_test() {
    local message="$1"
    if [[ -z "$message" ]]; then
        log_error "log_info_test requires a message parameter" >&2
        return 1
    fi

    if [[ $LOG_LEVEL -le $INFO ]]; then
        log_info "=== $message ==="
    fi
}

# Print warning message
# Arguments:
#   $1 - Message to print
log_warn() {
    local message="$1"
    if [[ -z "$message" ]]; then
        log_error "log_warn requires a message parameter" >&2
        return 1
    fi

    if [[ $LOG_LEVEL -le $WARN ]]; then
        echo "[WARN] $message" >&2
    fi
}

# Print error message
# Arguments:
#   $1 - Message to print
log_error() {
    local message="$1"
    if [[ -z "$message" ]]; then
        log_error "log_error requires a message parameter" >&2
        return 1
    fi

    if [[ $LOG_LEVEL -le $ERROR ]]; then
        echo "[ERROR] $message" >&2
    fi
}

# Print debug message if verbose mode is enabled
# Arguments:
#   $1 - Message to print
log_debug() {
    local message="$1"
    if [[ -z "$message" ]]; then
        log_error "log_debug requires a message parameter" >&2
        return 1
    fi

    if [[ $LOG_LEVEL -le $DEBUG ]]; then
        echo "[DEBUG] $message"
    fi
}

# Set the logging level
# Arguments:
#   $1 - Log level (1-4)
# Returns:
#   0 if successful, 1 if invalid input
set_log_level() {
    local level="$1"

    # Check if input is a number
    if ! [[ "$level" =~ ^[0-9]+$ ]]; then
        log_error "Log level must be a number" >&2
        return 1
    fi

    # Validate range
    if (( level < 1 || level > 4 )); then
        log_error "Log level must be between 1 and 4" >&2
        return 1
    fi

    LOG_LEVEL=$level
    return 0
}

# Helper functions to set specific log levels
set_log_level_debug() {
    set_log_level $DEBUG
}

set_log_level_info() {
    set_log_level $INFO
}

set_log_level_warn() {
    set_log_level $WARN
}

set_log_level_error() {
    set_log_level $ERROR
}

# Export functions
export -f log_info
export -f log_info_test
export -f log_warn
export -f log_error
export -f log_debug
export -f set_log_level_debug
export -f set_log_level_info
export -f set_log_level_warn
export -f set_log_level_error

