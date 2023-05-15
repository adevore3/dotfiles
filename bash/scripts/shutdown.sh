#!/bin/bash

kill_process() {
  local process=$1
  echo "INFO Killing $process"
  kill $(ps aux | grep -v grep | grep $process | awk '{print $2}')
}

sudo kill_process brave-browser
sudo kill_process idea
sudo kill_process google
sudo kill_process firefox
sudo kill_process mysql
sudo kill_process postman

sleep 3

echo "INFO Shutting down"
sudo shutdown -r now

