#!/bin/bash

source "${DOTFILES}/tmux/functions/tmux_send_command_every_session_window_pane.func"

# Important to save history across tmux sessions/windows/panes
# Only load if we haven't already loaded recently, uses a basic check of starting with history
tmux_send_command_every_session_window_pane "history -a; history -r"
# The below doesn't work because the $(...) executes right away and puts in an empty string
#tmux_send_command_every_session_window_pane "[[ $(history 2 | head -n1 | awk -F 'PST|PDT' '{print $2}') =~ ^history ]] || history -a; history -r"

# Set backup directory
BACKUP_DIR="$HOME/bash_history_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/bash_history_$TIMESTAMP.txt"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Copy bash history with timestamp header
echo "Bash History Backup - $TIMESTAMP" > "$BACKUP_FILE"
echo "--------------------------------" >> "$BACKUP_FILE"
cat "$HOME/.bash_history" >> "$BACKUP_FILE"

# Compress the backup
gzip "$BACKUP_FILE"

# Keep only last 30 backups
#find "$BACKUP_DIR" -name "bash_history_*.txt.gz" -type f -mtime +30 -delete

echo "Backup created: ${BACKUP_FILE}.gz"

