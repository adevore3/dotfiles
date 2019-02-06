# ls aliases
alias sl=ls
alias ls='ls -G'
alias la='ls -AF'
alias ll='ls -al'
alias l='ls -a'
alias l1='ls -1'

if [ $(uname) = "Linux" ]; then
  alias ls="ls --color=always"
fi

# navigating
alias -- -='cd -'
alias ....='cd ../../..'
alias ...='cd ../..'
alias ..='cd ..'

# monitor setup
alias mirror='xrandr --output DP-1 --output DP-2 --same-as DP-1'
alias rightoff='xrandr --output DP-2 --off'
alias righton="xrandr --output DP-2 --auto"
alias xq='xrandr -q' # Display monitor info

# misc
alias _='sudo'
alias ag='alias | grep'
alias apt-get="sudo apt-get"
alias cdp='cd -P'
alias diff='diff -W $(tput cols)'
alias dirs='dirs -v'
alias e='exit'
alias h1='head -n1'
alias h='history'
alias hg='history | grep '
alias hist=$'history | awk \'{print $2}\' | sort | uniq -c | sort -rn | head'
alias jp='f(){ j $1; cd -P .; unset -f f; }; f'
alias jq='jq -C'
alias kp=$'f(){ kill $(ps aux | grep -v grep | grep $1 | awk \'{print $2}\'); unset -f f; }; f'
alias locate_directory_with_the_most_files="locate '' | sed 's|/[^/]*$|/|g' | sort | uniq -c | sort -n | tee filesperdirectory.txt | tail"
alias md='mkdir -p'
alias path='echo $PATH'
alias pathg='echo $PATH | grep'
alias pathl='path | tr : "\n" | sort'
alias ports='netstat -tulanp'
alias psg='ps fauxwww | grep -v grep | grep'
alias rd='rmdir'
alias reload!='. ~/.bashrc'
alias t1='tail -n1'
alias update='sudo apt-get update && sudo apt-get upgrade'
alias updatey="sudo apt-get --yes"
alias vd='vi `git diff --name-only`'
alias watch='watch -c '

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias locate_directory_with_the_most_files="locate '' | sed 's|/[^/]*$|/|g' | sort | uniq -c | sort -n | tee filesperdirectory.txt | tail"

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

