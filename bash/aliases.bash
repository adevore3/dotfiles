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
alias dirs='dirs -v'

# misc
alias _='sudo'
alias dirs='dirs -v'
alias e='exit'
alias h='history'
alias hg='history | grep '
alias hist='history | awk '"'"'{print $2}'"'"' | sort | uniq -c | sort -rn | head'
alias locate_directory_with_the_most_files="locate '' | sed 's|/[^/]*$|/|g' | sort | uniq -c | sort -n | tee filesperdirectory.txt | tail"
alias md='mkdir -p'
alias path='echo $PATH'
alias pathl='path | tr : "\n" | sort'
alias psg='ps fauxwww | grep -v grep | grep'
alias rd='rmdir'
alias reload!='. ~/.bashrc'
alias vd='vi `git diff --name-only`'

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

