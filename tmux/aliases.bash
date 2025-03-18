alias ta='tmux a'
alias tat='tmux a -t'
alias taw='tmux a -t work'
alias tbp='tmux break-pane'
alias td='tmux detach'
alias tda='tmux detach -a'
alias tkp='tmux kill-pane -a'
alias tks='tmux kill-session -t'
alias tksw='tmux kill-session -t work'
alias tns='tmux new -s'
alias tnw='tmux new -s work'
alias trw='tmux rename-window'
alias trwd='tmux rename-window $(basename "$PWD")'
alias trwr='tmux rename-window $(basename $(git rev-parse --show-toplevel))'
alias trwj='tmux rename-window $(if [ -e repo.cfg ]; then fgrep "jira=" repo.cfg | cut -d= -f2; else echo $(basename "$PWD"); fi)'
alias trwm='tmux rename-window misc'
alias tsrac='tmux_save_reload_all_commands'

# Long commands
alias tmux_save_reload_all_commands='tmux_send_command_every_session_window_pane "history -a; history -r"'

# Alias for functions
alias cw='create_window_with_n_panes'
alias tsce='tmux_send_command_every_session_window_pane'

