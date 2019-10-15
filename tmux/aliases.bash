alias ta='tmux a -t'
alias taw='tmux a -t work'
alias tda='tmux detach -a'
alias tkp='tmux kill-pane -a'
alias tks='tmux kill-session -t'
alias tksw='tmux kill-session -t work'
alias tmux="`which tmux` -2"
alias tn='tmux new -s'
alias tnw='tmux new -s work'
alias trw='tmux rename-window'
alias trwd='tmux rename-window $(basename "$PWD")'
alias trwj='tmux rename-window $(if [ -e repo.cfg ]; then fgrep "jira=" repo.cfg | cut -d= -f2; else echo $(basename "$PWD"); fi)'
alias trwm='tmux rename-window misc'

# Alias for functions
alias cw='create_window_with_n_panes'
