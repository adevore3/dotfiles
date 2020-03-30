#!/bin/bash

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
  sudo python $DOTFILES/cheat/get-pip.py
  sudo pip install cheat
}

function install_autojump() {
  cd $DOTFILES/autojump
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
apt_install_template "figlet"
apt_install_template "fortune"
apt_install_template "htop"
apt_install_template "httpie"
apt_install_template "jq"
apt_install_template "tmux"
apt_install_template "tree"
apt_install_template "vim"
apt_install_template "wget"

echo "Installing submodules"
git submodule update --init --recursive

installing_template "cheat" install_cheat
installing_template "autojump" install_autojump

echo "Installing tmux plugins"
install_tmux_plugins

