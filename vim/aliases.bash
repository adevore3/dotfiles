alias vOggl='f(){ vi -O $(git grep -l "$*"); unset -f f; }; f'
alias vggl='f(){ vi $(git grep -l "$*"); unset -f f; }; f'
alias voggl='f(){ vi -o $(git grep -l "$*"); unset -f f; }; f'

