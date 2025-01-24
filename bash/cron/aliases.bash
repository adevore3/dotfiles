# history commands
alias find_dotfile_crons='find ${DOTFILES} -type f -name cron'
alias update_crons='f(){ \
  local -r crontab_file="${DOTFILES}/bash/cron/crontab-final"; \
  echo > $crontab_file; \
  find ${DOTFILES} -type f -name cron | xargs -I {} cat {} >> $crontab_file; \
  crontab $crontab_file; \
  crontab -l; \
  unset -f f; \
}; f'

