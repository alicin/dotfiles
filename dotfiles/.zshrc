export DOTFILESSRC="${DOTFILESSRC:-$HOME/labs/dotfiles}"

[[ -r "$DOTFILESSRC/lib/os-detection.sh" ]] && source "$DOTFILESSRC/lib/os-detection.sh"
[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"
