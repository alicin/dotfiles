export DOTFILESSRC="${DOTFILESSRC:-$HOME/labs/dotfiles}"

[[ -r "$DOTFILESSRC/lib/os-detection.sh" ]] && source "$DOTFILESSRC/lib/os-detection.sh"
[[ -r "$HOME/.config/zsh/init.zsh" ]] && source "$HOME/.config/zsh/init.zsh"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/ali/Downloads/gcloud/google-cloud-sdk/path.zsh.inc' ]; then . '/home/ali/Downloads/gcloud/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/ali/Downloads/gcloud/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/ali/Downloads/gcloud/google-cloud-sdk/completion.zsh.inc'; fi
