# short aliases
alias dkc=docker_kill_all_containers
alias drc=docker_remove_all_containers
alias dri=docker_remove_all_images
alias dsc=docker_stop_all_containers

# long aliases
alias docker_kill_all_containers="docker kill $(docker ps -q)" # kill all containers
alias docker_remove_all_containers="docker rm $(docker ps -a -q)" # remove all containers
alias docker_remove_all_images="docker rmi $(docker images -q)" # remove all docker images
alias docker_stop_all_containers="docker stop $(docker ps -q)" # stop all containers

