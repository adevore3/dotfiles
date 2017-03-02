#!/usr/bin/env bash

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# When changing directory small typos can be ignored by bash
# for example, cd /vr/lgo/apaache would find/var/log/apache
shopt -s cdspell

# colored grep
export GREP_COLOR='1;33'
unset GREP_OPTIONS

# colored ls
export LSCOLORS='Gxfxcxdxdxegedabagacad'

# Load the theme
source "${DOTFILES}/bash/prompt.bash"

# append to bash_history file, don't overwrite it
shopt -s histappend

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
export HISTCONTROL=ignoreboth

# Erase duplicates
export HISTCONTROL="ignoredups"
export HISTCONTROL=erasedups

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
export HISTSIZE=5000
export HISTFILESIZE=2000

export AUTOFEATURE=true autotest

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# add any tools or scripts in home bin
conditionally_prefix_path "${HOME}/bin"

# vi for the command line
set -o vi

# Set default editor
export VISUAL=vim
export EDITOR="$VISUAL"

# Set up for autojump
[[ -s /home/adevore/.autojump/etc/profile.d/autojump.sh ]] && source /home/adevore/.autojump/etc/profile.d/autojump.sh

