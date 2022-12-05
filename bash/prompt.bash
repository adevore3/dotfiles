SCM_THEME_PROMPT_DIRTY="${red}⚡${reset_color}"
SCM_THEME_PROMPT_AHEAD="${red}!${reset_color}"
SCM_THEME_PROMPT_CLEAN="${green}✓${reset_color}"
SCM_THEME_PROMPT_PREFIX=" "
SCM_THEME_PROMPT_SUFFIX=""
GIT_SHA_PREFIX=" ${yellow}"
GIT_SHA_SUFFIX="${reset_color}"

function git_short_sha() {
  SHA=$(git rev-parse --short HEAD 2> /dev/null) && echo "$GIT_SHA_PREFIX$SHA$GIT_SHA_SUFFIX"
}

function prompt() {
    local n_commands="\!"
    local vm="$(hostnamectl | sed -n '2p' | awkp 3)"
    if [ "$vm" = "computer-vm" ]; then
      vm=" $vm"
    else
      vm=""
    fi
    local user_host="${green}\h$vm${reset_color}"
    local prompt_symbol='λ'
    local node="${cyan}$(node_version_prompt)${reset_color}"
    local open='('
    local current_path="\w"
    local git_branch="$(git_short_sha)$(scm_prompt_info)"
    local close=')'
    local return_status=""
    local prompt_char=' \$ '

    PS1="\n${n_commands} ${user_host} ${prompt_symbol} $node ${open}${current_path}${git_branch}${close}${return_status}\n${prompt_char}"
}

PROMPT_COMMAND="prompt;history -a;history -r"

