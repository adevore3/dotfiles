alias cn='cat $DOTFILES/misc/notes.txt'
alias vn='vi $DOTFILES/misc/notes.txt'

alias ctf='~/dotfiles/misc/scripts/cloc-top-files.sh'
alias cloch='cloc $(git ls-files)'
alias dbeaver='nohup sh -c ~/dbeaver/dbeaver > /dev/null 2>&1 &'
alias first_sha='git log -n 1; git log -n 1 --format=%H | tr -d "\n" | tmux loadb -'
alias pm='nohup sh -c "postman \$*" > /dev/null 2>&1 &'
