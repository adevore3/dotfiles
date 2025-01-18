#!/bin/bash

# Source log utilities for logging
source "${DOTFILES}/bash/functions/log_utils.sh"

# Cache directory for storing instance information
if [[ ! ${CACHE_DIR+x} ]]; then
    readonly CACHE_DIR="/tmp/aws_cache"
fi
mkdir -p "${CACHE_DIR}"

#######################################
# Validates if an AWS profile exists and is usable
# Arguments:
#   $1 - AWS profile name
# Outputs:
#   None
# Returns:
#   0 if profile is valid and usable, non-zero otherwise
#######################################
validate_aws_profile() {
    local profile=$1

    if [[ ! $profile ]]; then
        log_error "Profile name is required"
        return 1
    fi

    # Check if profile exists in credentials file
    if ! grep -q "\[${profile}\]" ~/.aws/credentials 2>/dev/null; then
        log_warn "Profile '$profile' not found in AWS credentials"
        return 1
    fi

    # Test the profile with a simple API call
    if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
        log_error "Failed to validate AWS profile '$profile' - credentials may be invalid or expired"
        return 1
    fi

    log_info "Successfully validated AWS profile '$profile'"
    return 0
}

# Export all functions
export -f validate_aws_profile

