#!/bin/bash

# Enable error handling
set -e
set -o pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Print success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error message and exit
error() {
    echo -e "${RED}✗ $1${NC}" >&2
    exit 1
}

# Check required dependencies
echo "Checking dependencies..."
which aws >/dev/null 2>&1 || error "aws CLI is not installed"
success "Required dependencies are present"

# Source aws_utils.sh
echo "Sourcing aws_utils.sh..."
if [[ ! -f "aws_utils.sh" ]]; then
    error "aws_utils.sh not found in current directory"
fi

source ./aws_utils.sh || error "Failed to source aws_utils.sh"
success "Successfully sourced aws_utils.sh"

# Verify required functions exist
echo "Verifying exported functions..."
required_functions=(
    "validate_aws_profile"
    "get_instance_info"
    "get_cluster_instances"
    "get_active_clusters"
    "validate_cluster_name"
)

for func in "${required_functions[@]}"; do
    if ! declare -F "$func" >/dev/null; then
        error "Required function '$func' not found"
    fi
done
success "All required functions are present"

echo "All tests passed successfully!"
exit 0

