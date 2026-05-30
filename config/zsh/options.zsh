HISTSIZE=1000
SAVEHIST=1000
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

setopt append_history
setopt hist_ignore_dups
setopt hist_reduce_blanks
setopt share_history