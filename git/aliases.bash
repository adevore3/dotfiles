alias g='git'
alias ga='git add'
alias gall='git add .'
alias gau='git add -u'
alias gb='git branch'
alias gba='git branch -a'
alias gblt='for k in `git branch -r | perl -pe "s/^..(.*?)( ->.*)?$/\1/"`; do echo -e `git show --pretty=format:"%Cgreen%ci %Cred%cr%Creset" $k -- | head -n 1`\\t$k; done | sort -r'
alias gbr='git branch -r'
alias gc='git commit -v'
alias gca='git commit -v -a'
alias gci='git commit --interactive'
alias gcl='git clone'
alias gco='git checkout'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gdel='git branch -D'
alias gdv='git diff -w "$@" | vim -R -'
alias get='git'
alias gexport='git archive --format zip --output'
alias gg='git grep -n'
alias ggl='git grep -l'
alias gln='git log --name-status'
alias glo='git log --graph --pretty=oneline --abbrev-commit'
alias gmu='git fetch origin -v; git fetch upstream -v; git merge upstream/master'
alias gp='git push'
alias gpo='git push origin'
alias grm="git status | grep deleted | awk '{print \$3}' | xargs git rm"
alias grt='cd $(git rev-parse --show-cdup)'
alias gs='git status'
alias gsfp='git stash show -p | git apply && git stash drop'
alias gss='git status -s'
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