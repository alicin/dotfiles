typeset -g ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-${${(%):-%N}:A:h}}"

_zsh_source() {
  local file="$ZSH_CONFIG_DIR/$1"
  [[ -r "$file" ]] && source "$file"
}

_zsh_source env.zsh
_zsh_source path.zsh
_zsh_source options.zsh

if [[ -o interactive && "${ZSH_START_AT_BOTTOM:-1}" != 0 ]]; then
  printf '\n%.0s' {1..100}
fi

[[ -o interactive ]] && _zsh_source plugins.zsh
_zsh_source aliases.zsh
_zsh_source functions.zsh

host_config="$ZSH_CONFIG_DIR/hosts/${HOSTNAME:-$(hostname 2>/dev/null)}.zsh"
[[ -r "$host_config" ]] && source "$host_config"

unfunction _zsh_source
unset host_config