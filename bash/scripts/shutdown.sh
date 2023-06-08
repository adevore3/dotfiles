#!/bin/bash

kill_process() {
  local process=$1
  local process_id=$(ps aux | grep -v grep | grep $process | head -n1 | awk '{print $2}')
  if [ -z "$process_id" ]; then
    echo INFO $process not currently running
  else
    echo INFO Killing $process
    killall $process
  fi
}

kill_process brave
kill_process idea
kill_process google
kill_process firefox
kill_process mysql
kill_process postman

sleep 3

echo INFO Shutting down
sudo shutdown now

