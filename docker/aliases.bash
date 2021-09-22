# short aliases
alias dkac=docker_kill_all_containers
alias drac=docker_remove_all_containers
alias drai=docker_remove_all_images
alias druc=docker_remove_unused_containers
alias drui=docker_remove_unused_images
alias dsac=docker_stop_all_containers

# long aliases
alias docker_kill_all_containers='docker kill $(docker ps -q)'
alias docker_nuke='docker system prune'
alias docker_remove_all_containers='docker rm $(docker ps -a -q)'
alias docker_remove_all_images='docker rmi $(docker images -q)'
alias docker_remove_unused_containers='docker rm $(docker ps -qa --no-trunc --filter "status=exited")'
alias docker_remove_unused_images='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'
alias docker_stop_all_containers='docker stop $(docker ps -q)'

