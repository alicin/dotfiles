# Source OS detection script
source $HOME/labs/dotfiles/lib/os-detection.sh

printf '\n%.0s' {1..100}

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
  z
  )
  
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
source $ZSH/oh-my-zsh.sh

source ~/.config/zsh/var.conf
source ~/.config/zsh/aliases.conf
source ~/.config/zsh/functions.sh

fpath=($fpath "$HOME/.zfunctions")

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff"

# # Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
if [[ "$(uname)" == "Darwin" ]]; then
  fpath=(/Users/ali/.docker/completions $fpath)
  autoload -Uz compinit
  compinit
fi
# End of Docker CLI completions

eval $(thefuck --alias)
eval "$(starship init zsh)"


if [[ "$(uname)" == "Linux" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
eval "$(atuin init zsh)"
eval "$(fnm env --use-on-cd --shell zsh)"

# pnpm
export PNPM_HOME="/home/ali/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
