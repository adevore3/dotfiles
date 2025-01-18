#!/bin/bash

# Source bash utilities for logging
# shellcheck source=bash_utils.sh
source "${DOTFILES}/bash/functions/bash_utils.sh"

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

#######################################
# Fetches and caches EC2 instance information for a given profile
# Arguments:
#   $1 - AWS profile name
# Outputs:
#   Instance information in JSON format
# Returns:
#   0 if successful, non-zero on error
#######################################
get_instance_info() {
    local profile=$1
    local cache_file="${CACHE_DIR}/instances_${profile}.json"

    if [[ ! $profile ]]; then
        log_error "Profile name is required"
        return 1
    fi

    # Check if cache exists and is less than 5 minutes old
    if [[ -f $cache_file ]] && [[ $(find "$cache_file" -mmin -5) ]]; then
        log_info "Using cached instance info for profile $profile"
        cat "$cache_file"
        return 0
    fi

    log_info "Fetching fresh instance info for profile $profile"
    if ! aws ec2 describe-instances --profile "$profile" > "$cache_file"; then
        log_error "Failed to fetch instance information"
        return 1
    fi

    cat "$cache_file"
    return 0
}

#######################################
# Gets instances for a specific EMR cluster
# Arguments:
#   $1 - Cluster ID
#   $2 - AWS profile name (optional)
# Outputs:
#   Instance information in JSON format
# Returns:
#   0 if successful, non-zero on error
#######################################
get_cluster_instances() {
    local cluster_id=$1
    local profile=$2
    local profile_arg=""

    if [[ ! $cluster_id ]]; then
        log_error "Cluster ID is required"
        return 1
    fi

    if [[ $profile ]]; then
        profile_arg="--profile $profile"
    fi

    if ! aws emr list-instances --cluster-id "$cluster_id" $profile_arg; then
        log_error "Failed to get instances for cluster $cluster_id"
        return 1
    fi

    return 0
}

#######################################
# Lists all active EMR clusters
# Arguments:
#   $1 - AWS profile name (optional)
# Outputs:
#   Active cluster information in JSON format
# Returns:
#   0 if successful, non-zero on error
#######################################
get_active_clusters() {
    local profile=$1
    local profile_arg=""

    if [[ $profile ]]; then
        profile_arg="--profile $profile"
    fi

    if ! aws emr list-clusters --cluster-states STARTING BOOTSTRAPPING RUNNING WAITING $profile_arg; then
        log_error "Failed to list active clusters"
        return 1
    fi

    return 0
}

#######################################
# Validates if a cluster exists and is active
# Arguments:
#   $1 - Cluster name or ID
#   $2 - AWS profile name (optional)
# Outputs:
#   None
# Returns:
#   0 if cluster exists and is active, non-zero otherwise
#######################################
validate_cluster_name() {
    local cluster=$1
    local profile=$2
    local profile_arg=""
    local cluster_status

    if [[ ! $cluster ]]; then
        log_error "Cluster name or ID is required"
        return 1
    fi

    if [[ $profile ]]; then
        profile_arg="--profile $profile"
    fi

    # Check if input is a cluster ID
    if [[ $cluster =~ ^j-[A-Z0-9]{13}$ ]]; then
        cluster_status=$(aws emr describe-cluster --cluster-id "$cluster" $profile_arg --query 'Cluster.Status.State' --output text 2>/dev/null)
    else
        # Search by cluster name
        cluster_status=$(aws emr list-clusters $profile_arg --query "Clusters[?Name=='${cluster}'].Status.State" --output text 2>/dev/null)
    fi

    if [[ ! $cluster_status ]]; then
        log_warn "Cluster $cluster not found"
        return 1
    fi

    case $cluster_status in
        STARTING|BOOTSTRAPPING|RUNNING|WAITING)
            return 0
            ;;
        *)
            log_warn "Cluster $cluster is not active (status: $cluster_status)"
            return 1
            ;;
    esac
}

# Export all functions
export -f validate_aws_profile
export -f get_instance_info
export -f get_cluster_instances
export -f get_active_clusters
export -f validate_cluster_name

