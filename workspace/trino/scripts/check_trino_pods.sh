#!/bin/bash

source "${DOTFILES}/bash/functions/cap.func"
source "${DOTFILES}/bash/functions/log_utils.sh"
source "${DOTFILES}/bash/functions/ret.func"

# Default profile
ENV=""

# Parse command line arguments
while getopts "e:" opt; do
    case $opt in
        e)
            ENV="$OPTARG"
            ;;
        \?)
            log_error "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

# Validate ENV
VALID_ENVS=("stage" "interactive" "prod")
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

NAMESPACE=""
case $ENV in
    stage)
      NAMESPACE="trino--stage" ;;
    iteractive)
      NAMESPACE="trino--interactive" ;;
    prod)
      NAMESPACE="trino--prod" ;;
    *)
      log_error "Invalid ENV: '$ENV'. Must be one of: ${VALID_ENVS[*],,}"
      exit 1
      ;;
esac

kubectl -n $NAMESPACE get pods | cap $NAMESPACE get pods

output=$(ret $NAMESPACE get pods)

echo "$(echo "$output" | grep worker | wc -l) workers"
echo "$(echo "$output" | grep worker | grep Running | wc -l) running workers"
