#!/bin/env bash

function installing_template() {
  local program_name=$1;
  local installation_function=$2;

  echo "Checking for the existence of '$program_name'"
  if hash $program_name 2>/dev/null; then
    echo "  '$program_name' already installed, skipping"
  else
    echo "  Installing '$program_name'..."
    $2 $3
    echo "  Successfully installed '$program_name'"
  fi
}

function install_cheat() {
  echo "  Installing cheat version 4.4.0. For latest version check out https://github.com/cheat/cheat/blob/master/INSTALLING.md"

  cd /tmp \
    && wget https://github.com/cheat/cheat/releases/download/4.4.0/cheat-linux-amd64.gz \
    && gunzip cheat-linux-amd64.gz \
    && chmod +x cheat-linux-amd64 \
    && sudo mv cheat-linux-amd64 /usr/local/bin/cheat

  cd $DOTFILES/cheat/cheatsheets/
  git clone https://github.com/cheat/cheatsheets community
}

function install_autojump() {
  cd $DOTFILES/autojump/autojump
  ./install.py
}

function install_tmux_plugins() {
  # Start a session to install plugins
  tmux new -d -s test
  $DOTFILES/tmux/plugins/tpm/bindings/install_plugins
  tmux kill-session -t test
}

function apt_install_template() {
  f() {
    sudo apt install $1
  }
  installing_template $1 f $1
}

echo "Installing various commands"
apt_install_template "cowsay"
apt_install_template "diodon"
apt_install_template "figlet"
apt_install_template "fortune"
apt_install_template "htop"
apt_install_template "httpie"
apt_install_template "jq"
apt_install_template "net-tools"
apt_install_template "rename"
apt_install_template "silversearcher-ag"
apt_install_template "tmux"
apt_install_template "tree"
apt_install_template "vim"
apt_install_template "wget"

export DOTFILES=${DOTFILES:-/home/$(whoami)/dotfiles}

installing_template "autojump" install_autojump
installing_template "cheat" install_cheat

echo "Installing tmux plugins"
install_tmux_plugins

echo 'Things that may manually need installing/updating:'
echo '  * Brave Browser: https://brave.com/linux/'
echo '  * Update gitignore: concat_multiple_gitignores'
echo '  * Set .localrc per host'
echo '  * Verify autojump, cheat & tmux works'

