#!/bin/bash

if [ $# -ne 1 ] ; then
  echo "No server specified"
  exit 1
fi

ping -c 1 $1
if [ "$?" = 0 ] ; then
  ssh-copy-id $1
  scp ~/dotfiles/misc/.vimrc_ssh $1:~/.vimrc
  scp ~/dotfiles/misc/.bashrc_ssh $1:~/.bashrc
fi
