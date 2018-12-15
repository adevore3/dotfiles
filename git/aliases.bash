alias g='git'
alias ga='git add'
alias gaia='echo -e "a\n*\nq\n" | git add -i'
alias gall='git add .'
alias gau='git add -u'
alias gb='git branch'
alias gba='git branch -a'
alias gblt='for k in `git branch | perl -pe "s/^..(.*?)( ->.*)?$/\1/"`; do echo -e `git show --pretty=format:"%Cgreen%ci %Cred%cr%Creset" $k -- | head -n 1`\\t$k; done | sort -r'
alias gbr='git branch -r'
alias gbrlt='for k in `git branch -r | perl -pe "s/^..(.*?)( ->.*)?$/\1/"`; do echo -e `git show --pretty=format:"%Cgreen%ci %Cred%cr%Creset" $k -- | head -n 1`\\t$k; done | sort -r'
alias gbrv='git branch -rv'
alias gbvv='git branch -vv'
alias gcl='git clone'
alias gco='f(){ local branch=$(git branch -r | grep -i $1 | tr -d "[:space:]"); git checkout $branch; unset -f f; }; f'
alias gcob='git checkout -b'
alias gcobi='f(){ local branch=$(git checkout jira/$(whoami)/$branch; unset -f f; }; f'
alias gcorb='f(){ local branch=$(git branch -r | grep -i $1 | tr -d "[:space:]" | cut -c 8-); git checkout -b $branch origin/$branch; unset -f f; }; f'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gdv='git diff -w "$@" | vim -R -'
alias gg='git grep -n'
alias ggl='git grep -l'
alias glg='git log --grep'
alias gln='git log -n'
alias glns='git log --name-status'
alias glo='git log --graph --pretty=oneline --abbrev-commit'
alias gmu='git fetch origin -v; git fetch upstream -v; git merge upstream/master'
alias gp='git push'
alias gpo='git push origin'
alias grm="git status | grep deleted | awk '{print \$2}' | xargs git rm"
alias grt='cd $(git rev-parse --show-cdup)'
alias gsd='git_stashdrop'
alias gsfp='git stash show -p | git apply && git stash drop'
alias gsl='git stash list'
alias gsp='git stash pop'
alias gspm='git stash push -m'
alias gss='git_stashow'
alias gssp='git_stashowp'
alias gst='git status'
alias gup='git pull --rebase'

case $OSTYPE in
  linux*)
    alias gd='git diff | vim -R -'
    ;;
  darwin*)
    alias gd='git diff | mate'
    ;;
  darwin*)
    alias gd='git diff'
    ;;
esac
