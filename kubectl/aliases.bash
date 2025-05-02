alias ktgp='kube_trino_get_pods'
alias ktcbs='kube_trino_coordinator_bash_shell'
alias ktcbc='kube_trino_coordinator_bash_command'
alias ktcr='kube_trino_coordinator_restart'

# Long alias names
alias kube_trino_get_pods='f(){ kubectl -n "trino--$1" get pods; unset -f f; }; f'
alias kube_trino_coordinator_bash_shell=$'f(){ kubectl exec -it -n "trino--$1" $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\') -- /bin/bash; unset -f f; }; f'
alias kube_trino_coordinator_bash_command=$'f(){ kubectl exec -n "trino--$1" $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\') -- bash -c "$2"; unset -f f; }; f'
alias kube_trino_coordinator_restart=$'f(){ kubectl -n "trino--$1" rollout restart deployment "trino-aws$1-coordinator"; unset -f f; }; f'

