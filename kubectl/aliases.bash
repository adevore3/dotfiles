alias ktcbc='kube_trino_coordinator_bash_command'
alias ktcbs='kube_trino_coordinator_bash_shell'
alias ktccl='kube_trino_coordinator_container_logs'
alias ktcd='kube_trino_coordinator_describe'
alias ktcgp='kube_trino_coordinator_get_pod'
alias ktcl='kube_trino_coordinator_logs'
alias ktcr='kube_trino_coordinator_restart'
alias ktgp='kube_trino_get_pods'
alias ktlc='kube_trino_list_containers'

# Aliases for trino--dev
alias ktdcbc='kube_trino_coordinator_bash_command dev'
alias ktdcbs='kube_trino_coordinator_bash_shell dev'
alias ktdccl='kube_trino_coordinator_container_logs dev'
alias ktdcd='kube_trino_coordinator_describe dev'
alias ktdcgp='kube_trino_coordinator_get_pod dev'
alias ktdcl='kube_trino_coordinator_logs dev'
alias ktdcr='kube_trino_coordinator_restart dev'
alias ktdgp='kube_trino_get_pods dev'
alias ktdlc='kube_trino_list_containers dev'


# Long alias names
alias kube_trino_coordinator_bash_command=$'f(){ kubectl exec -n "trino--$1" $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\') -- bash -c "$2"; unset -f f; }; f'
alias kube_trino_coordinator_bash_shell=$'f(){ kubectl exec -it -n "trino--$1" $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\') -- /bin/bash; unset -f f; }; f'
alias kube_trino_coordinator_container_logs=$'f(){ kubectl -n "trino--$1" logs -f $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\') -c "$2"; unset -f f; }; f'
alias kube_trino_coordinator_describe=$'f(){ kubectl -n "trino--$1" describe pod $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\'); unset -f f; }; f'
alias kube_trino_coordinator_get_pod=$'f(){ kubectl -n "trino--$1" get pod $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\') -o yaml; unset -f f; }; f'
alias kube_trino_coordinator_logs=$'f(){ kubectl -n "trino--$1" logs -f $(kubectl -n "trino--$1" get pods | grep coordinator | awk \'{print $1}\'); unset -f f; }; f'
alias kube_trino_coordinator_restart=$'f(){ kubectl -n "trino--$1" rollout restart deployment "trino-aws$1-coordinator"; unset -f f; }; f'
alias kube_trino_get_pods='f(){ kubectl -n "trino--$1" get pods; unset -f f; }; f'
alias kube_trino_list_containers=$'f(){ kubectl -n "trino--$1" get pods -o jsonpath='{.items[*].spec.containers[*].name}'; unset -f f; }; f'

