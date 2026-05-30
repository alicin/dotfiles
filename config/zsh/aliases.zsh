alias zshconfig="$EDITOR ~/.zshrc"
alias zshdir="$EDITOR ~/.config/zsh"
alias ohmyzsh="$EDITOR $ZSH"
alias mkdir='mkdir -pv'
alias murder='command rm -rf'

if command -v trash >/dev/null 2>&1; then
  alias rm='trash'
fi