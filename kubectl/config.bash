# Guarded: kubectl is not installed everywhere, and unguarded this errors at every shell startup and trips
# command_not_found_handle, printing the figlet/cowsay banner.
type kubectl &> /dev/null && source <(kubectl completion bash)

