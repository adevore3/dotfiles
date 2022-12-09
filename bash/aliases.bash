# ls aliases
alias l1='ls -1'
alias l='ls -a'
alias la='ls -AF'
alias ll='ls -al'
alias llh='ls -ld .[!.]?*' # list hidden files
alias lls='ls -ld .?* | grep "\->"' # list symlinks
alias ls='ls -G'
alias sl=ls

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

# history commands
alias h='history'
alias hclr='history -c'
alias hdel='history -d'
alias hg='history | grep'
alias ht='history | tail'
alias htt='hist_top_ten'
alias hist_delete_all=$'f(){ sed -i "/$1/d" ~/.bash_history; unset -f f; }; f'
alias hist_disable='set +o history'
alias hist_enable='set -o history'
alias hist_top_ten=$'history | awk -F "PST|PDT" \'{print $2}\' | sort | uniq -c | sort -rn | head'


# misc
alias _='sudo'
alias acg='all_commands_grep'
alias ackg="$(which ag)"
alias ag='alias | grep -i'
alias agx='alias_grep_execute'
alias ccg='compgen -c | grep -i'
alias cdp='cd -P'
alias cfg='compgen -A function | grep -i'
alias d-d='f(){ date -d @"$1"; unset -f f; }; f'
alias diff='diff -W $(tput cols)'
alias dirs='dirs -v'
alias ejh='echo $JAVA_HOME'
alias envg='env | grep -i'
alias findg='find_grep'
alias hd1='head -n1'
alias hdn='head -n'
alias hl='highlight'
alias jp='f(){ j $1; cd -P .; unset -f f; }; f'
alias jq='jq -C'
alias kp='kill_process'
alias lsg='f(){ ls | grep -i "$1"; unset -f f; }; f'
alias md='mkdir -p'
alias meh='echo "¯\_(ツ)_/¯" | xclip -selection clipboard'
alias meh_escaped='echo "¯\\\_(ツ)\_/¯" | xclip -selection clipboard'
alias otp='open_time_picture'
alias path='echo $PATH'
alias pathg='echo $PATH | grep'
alias pathl='path | tr : "\n" | sort'
alias ports='sudo netstat -tulanp'
alias psg='ps fauxwww | grep -v grep | grep'
alias reload!='. ~/.bashrc'
alias restart_now='sudo shutdown -r now'
alias rls='rename_last_screenshot'
alias rtype='recursive_type'
alias sai='sudo apt install'
alias saiy='sudo apt install -y'
alias sar='sudo apt remove'
alias sauu='sudo apt update && sudo apt upgrade'
alias shrug='meh'
alias shutdown_now='sudo shutdown now'
alias start_custom='$DOTFILES/bash/scripts/startup.sh'
alias stop_custom='$DOTFILES/bash/scripts/shutdown.sh'
alias skp='sudo_kill_process'
alias tl1='tail -n1'
alias tln='tail -n'
alias vgd='vi `git diff --name-only`'
alias vil='vi !$'
alias vilc='vi $(fc -s)'
alias watch='watch -c '
alias xclipf='xclip -sel clip'

# misc long names
alias generic_for_loop=$'f(){ local count=$1; local exp_command=$2; for ((i=1; i<=$count; i++)); do eval $exp_command; done; unset -f f; }; f'
alias kill_process=$'f(){ kill $(ps aux | grep -v grep | grep $1 | awk \'{print $2}\'); unset -f f; }; f'
alias locate_directory_with_the_most_files="locate '' | sed 's|/[^/]*$|/|g' | sort | uniq -c | sort -n | tee filesperdirectory.txt | tail"
alias open_time_picture='xdg-open $DOTFILES/misc/pictures/backgrounds/is_it_worth_the_time.png'
alias sudo_kill_process=$'f(){ sudo kill $(ps aux | grep -v grep | grep $1 | awk \'{print $2}\'); unset -f f; }; f'

alias locate_directory_with_the_most_files="locate '' | sed 's|/[^/]*$|/|g' | sort | uniq -c | sort -n | tee ,filesperdirectory | tail"

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# example of changing an alias based on ostypes
case $OSTYPE in
  linux*)
    alias ostype="echo $OSTYPE"
    ;;
  darwin*)
    alias ostype="echo $OSTYPE"
    ;;
  darwin*)
    alias ostype="echo $OSTYPE"
    ;;
esac

