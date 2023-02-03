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
  if hash go 2>/dev/null; then
    go install github.com/cheat/cheat/cmd/cheat@latest
  else
    echo "  Unable to install cheat, 'go' not available (hash go)"
  fi
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
apt_install_template "clipit"
apt_install_template "cowsay"
apt_install_template "figlet"
apt_install_template "fortune"
apt_install_template "htop"
apt_install_template "httpie"
apt_install_template "jq"
apt_install_template "silversearcher-ag"
apt_install_template "tmux"
apt_install_template "tree"
apt_install_template "vim"
apt_install_template "wget"

installing_template "cheat" install_cheat
installing_template "autojump" install_autojump

echo "Installing tmux plugins"
install_tmux_plugins

echo "Things that may manually need installing/updating:"
echo "  * Brave Browser: https://brave.com/linux/"
echo "  * Update gitignore: concat_multiple_gitignores"

