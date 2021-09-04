#!/usr/bin/env bash

# tell tmux that the terminal type is 'screen-256color' regardless of what the
# terminal says. the $TERM environment variable is the second place where tmux
# inherits its terminal type
export TERM="screen-256color"

