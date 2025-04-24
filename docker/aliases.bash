# general
alias dps='docker ps'
alias dkp='docker_kill_process'
alias dcomp='docker-compose'
alias dose='docker-compose'

# short aliases
alias dkac=docker_kill_all_containers
alias drac=docker_remove_all_containers
alias drai=docker_remove_all_images
alias druc=docker_remove_unused_containers
alias drui=docker_remove_unused_images
alias dsac=docker_stop_all_containers

# long aliases
alias docker_kill_all_containers='docker kill $(docker ps -q)'
alias docker_kill_process=$'f() { docker kill $(docker ps | grep spark | awk \'{print $1}\'); unset -f f; }; f'
alias docker_nuke='docker system prune'
alias docker_remove_all_containers='docker rm $(docker ps -a -q)'
alias docker_remove_all_images='docker rmi $(docker images -q)'
alias docker_remove_unused_containers='docker rm $(docker ps -qa --no-trunc --filter "status=exited")'
alias docker_remove_unused_images='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'
alias docker_stop_all_containers='docker stop $(docker ps -q)'

