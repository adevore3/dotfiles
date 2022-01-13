#!/bin/bash

# This script

if ! [ -x "$(command -v cloc)" ]; then
  echo "'cloc' command needed to calculate lines"
fi

desired_num_files=5

undesired_file_types="json|png|svg|snap|po"

# 1. Find unique file types
# 2. Count & sort file types
# 3. Filter & limit file types
# 4. Transform file types for filter
desired_files=$(git ls-files | rev | cut -d'.' -f1 | rev \
  | sort | uniq -c | sort -rg \
  | egrep -v "($undesired_file_types)" | head -n $desired_num_files \
  | awk '{print $2}' | sed -e 's/$/\$/' | sed -e 's/^/\./' | sed ':a; N; $!ba; s/\n/|/g')

echo "desired files: '$desired_files'"

desired_git_files=$(git ls-files | egrep "($desired_files)")

cloc $desired_git_files

