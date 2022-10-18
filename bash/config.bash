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
export HISTIGNORE='\.\.:\.\.\.:ag*:exit:gst:gup:hg*:history*:htop:ij:ll:ls:tnw:tnwi:umr:[ ]*'
export HISTTIMEFORMAT="%c "
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

# set default editor
export VISUAL=vim
export EDITOR="$VISUAL"

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile)
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# set up for autojump
[[ -s $HOME/.autojump/etc/profile.d/autojump.sh ]] && source $HOME/.autojump/etc/profile.d/autojump.sh

# set up less with pygmentize
export LESS='-R'
export LESSOPEN='|~/.lessfilter %s'

# set up less with better highlighting (especially in tmux)
export LESS_TERMCAP_so=$'\E[01;33;03;40m'

# set up custom command_not_found handle
command_not_found_handle () {
    if [ -x "$(command -v figlet)" ] && [ -x "$(command -v fortune)" ] && [ -x "$(command -v cowsay)" ]; then
        { echo NOPE | figlet; fortune; } | cowsay -f stegosaurus -n
    else
        echo "'$1' not found"
    fi
    return 127
}

