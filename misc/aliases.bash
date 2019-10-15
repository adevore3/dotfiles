alias cn='cat $DOTFILES/misc/notes.txt'
alias vn='vi $DOTFILES/misc/notes.txt'

alias dbeaver='nohup sh -c ~/dbeaver/dbeaver > /dev/null 2>&1 &'
alias first_sha='git log -n 1; git log -n 1 --format=%H | tr -d "\n" | tmux loadb -'
alias pm='postman'
alias postman='nohup sh -c "~/Postman/Postman \$*" > /dev/null 2>&1 &'
