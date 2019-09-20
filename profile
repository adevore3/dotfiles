# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# BEGIN env Setup -- Managed by Ansible DO NOT EDIT.

# Single-brace syntax because this is required in bash, dash, zsh, etc
if [ -e "$HOME/env/etc/indeed_profile" ]; then
    . "$HOME/env/etc/indeed_profile"
fi

# Add ~/env/bin to your PATH to use the shared shell scripts from delivery/env
if [ -d "$HOME/env/bin" ]; then
    PATH="$HOME/env/bin:$PATH"
fi

# On OSX, explicitly source .bashrc so that OS X bash is guaranteed to include all definitions, changing .bashrc to .zshrc for zsh
if [ "Darwin" = "$(uname -s)" ]; then
    [ -s "$HOME/.bashrc" ] && . "$HOME/.bashrc"
fi

# Add dev tool binaries to path
if [ -d "$HOME/.indeed-dev-tools/bin" ]; then
    PATH="$HOME/.indeed-dev-tools/bin:$PATH"
fi

# Add javadev binaries to path
if [ -d "$INDEED_JAVADEV_DIR/bin" ]; then
    PATH="$INDEED_JAVADEV_DIR/bin:$PATH"
fi
# END env Setup -- Managed by Ansible DO NOT EDIT.

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
      . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

