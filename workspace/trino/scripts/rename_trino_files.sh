#!/bin/bash

source "${DOTFILES}/bash/functions/from_unixtime.func"

for file in $(ls | grep "^trino" | grep -v 2025); do
#  echo file: $file
  timestamp=$(echo $file | cut -d_ -f2 | cut -d. -f1)
#  echo timestamp: $timestamp
  file_prefix=$(echo $file | cut -d_ -f1)
#  echo file_prefix: $file_prefix
  date_time=$(from_unixtime -f date_time $timestamp)
#  echo date_time: $date_time
  cp $file ${file_prefix}_${date_time}.json
done

