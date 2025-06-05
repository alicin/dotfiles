# CodeWhisperer pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.pre.zsh"
printf '\n%.0s' {1..100}

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

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

source $ZSH/oh-my-zsh.sh

source ~/.config/zsh/var.conf
source ~/.config/zsh/aliases.conf
source ~/.config/zsh/functions.sh
source ~/.config/zsh/style.conf
source ~/.config/zsh/init.sh
source ~/.config/zsh/launcher.conf

fpath=($fpath "$HOME/.zfunctions")

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# CodeWhisperer post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.post.zsh"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"


# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/ali/.lmstudio/bin"

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
