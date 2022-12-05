#!/bin/bash

kill_process() {
  kill $(ps aux | grep -v grep | grep $1 | awk '{print $2}')
}

kill_process brave-browser
kill_process idea
kill_process google
kill_process firefox
kill_process mysql
kill_process postman

sudo shutdown -r now

