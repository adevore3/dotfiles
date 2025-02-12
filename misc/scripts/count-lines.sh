#!/bin/bash

source "${DOTFILES}/bash/functions/log_utils.sh"

if ! [ -x "$(command -v cloc)" ]; then
  log_info "'cloc' command needed to calculate lines"
fi

# This is not accurate because it checks the file at the current version
# For a more accurate count we would need to check out each commit and then
# run cloc against the files for that sha
for commit in $(git log --reverse --format="%H,%as" origin/master); do
  git_hash=$(echo $commit | cut -d, -f1)
  date_time=$(echo $commit | cut -d, -f2)

  git checkout $git_hash

  log_info "$date_time,$(cloc --quiet --diff-timeout 20 $(git ls-tree --name-only -r $git_hash) | grep SUM | awk -vfield="5" '{print $field}')"
done

