#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"

for commit in $(git log --reverse --format="%H,%as" origin/master); do
  git_hash=$(echo $commit | cut -d, -f1)
  date_time=$(echo $commit | cut -d, -f2)

  log_info "$date_time,$(git ls-tree --name-only -r $git_hash | wc -l)"
done

