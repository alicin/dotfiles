typeset -U fpath

for dir in /usr/share/zsh/site-functions /usr/share/zsh/vendor-completions /usr/share/zsh/functions/*(/N); do
  fpath=("$dir" $fpath)
done

[[ -d "$HOME/.zfunctions" ]] && fpath=("$HOME/.zfunctions" $fpath)

if [[ "$(uname)" == "Darwin" && -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
  z
)

export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH/cache/.zcompdump-$HOST}"
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff"

if [[ -r "$HOME/.atuin/bin/env" ]]; then
  source "$HOME/.atuin/bin/env"
fi

if command -v thefuck >/dev/null 2>&1; then
  eval "$(thefuck --alias)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
else
  if [[ ! -s "$NVM_DIR/nvm.sh" && -s "$HOME/.nvm/nvm.sh" ]]; then
    export NVM_DIR="$HOME/.nvm"
  fi
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
fi

[[ -r "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"