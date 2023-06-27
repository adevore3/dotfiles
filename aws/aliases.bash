alias acl='aws configure list'
alias aclp='aws configure list-profiles'
alias asgci='aws sts get-caller-identity'
alias caco='cat ~/.aws/config'
alias cacr='cat ~/.aws/credentials'
alias cacrg='f(){ cat ~/.aws/credentials | grep -A 4 $1 | tee >(tmux loadb -) | tee >(xclip -selection c); unset -f f; }; f'
alias vaco='vi ~/.aws/config'
alias vacr='vi ~/.aws/credentials'

