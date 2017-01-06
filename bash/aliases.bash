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
alias lre='vi ~/.localrc'
alias lrs='source ~/.localrc'
alias md='mkdir -p'
alias path='echo $PATH'
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

# Marchex related
alias cg='confgen'
alias cgd='confgen --dev'
alias dbeaver='nohup sh -c ~/dbeaver/dbeaver > /dev/null 2>&1 &'
alias first_sha='git log -n 1; git log -n 1 --format=%H | tr -d "\n" | tmux loadb -'
alias ij='/opt/scripts/startIdea.sh'
alias java6='export JAVA_HOME=/site/jdk/jdk1.6.0_37'
alias java7='export JAVA_HOME=/site/jdk/jdk1.7.0_17'
alias java8='export JAVA_HOME=/site/jdk/jdk1.8.0_60'
alias sp='ssh pulleybuild'

function oraprod () {
    USER="$1"
    PASS="$2"
    if [ -z $USER ]; then
      echo -n "Username: "
      stty -echo
      read USER
      stty echo
      echo
    fi;
    if [ -z $PASS ]; then
      echo -n "Password: "
      stty -echo
      read PASS
      stty echo
      echo
    fi;
    rlwrap $ORACLE_HOME/bin/sqlplus ${USER}/${PASS}@OPNEXT
}

function oraqa () {
    USER="$1"
    PASS="$2"
    if [ -z $USER ]; then
      echo -n "Username: "
      stty -echo
      read USER
      stty echo
      echo
    fi;
    if [ -z $PASS ]; then
      echo -n "Password: "
      stty -echo
      read PASS
      stty echo
      echo
    fi;
    rlwrap $ORACLE_HOME/bin/sqlplus ${USER}/${PASS}@OQ3NEXT
}

function oradev () {
    DEV="$1"
    USER="$2"
    PASS="$3"
    if [ -z $DEV ]; then
      echo -n "ODNEXT instance (some numeric number ie '34'): "
      stty -echo
      read DEV
      stty echo
      echo
    fi;
    if [ -z $USER ]; then
      echo -n "Username: "
      stty -echo
      read USER
      stty echo
      echo
    fi;
    if [ -z $PASS ]; then
      echo -n "Password: "
      stty -echo
      read PASS
      stty echo
      echo
    fi;
    rlwrap $ORACLE_HOME/bin/sqlplus "$2/$3@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=odnextx.qa.marchex.com)(PORT=7352))(CONNECT_DATA=(SERVICE_NAME=ODNEXT$1)))"
}
