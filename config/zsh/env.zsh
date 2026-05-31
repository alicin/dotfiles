export DOTFILESSRC="${DOTFILESSRC:-$HOME/labs/dotfiles}"

# Pick the first installed command from a preference list.
_first_cmd() {
  local cmd
  for cmd in "$@"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s' "$cmd"
      return 0
    fi
  done
  return 1
}

export EDITOR="${EDITOR:-$(_first_cmd micro nano code nvim vim vi)}"
export VISUAL="${VISUAL:-$(_first_cmd code nvim micro)}"
export PAGER="${PAGER:-$(_first_cmd less more)}"

if [[ "$(uname)" != "Darwin" ]]; then
  # macOS resolves these via `open`/LaunchServices, so only set on Linux/BSD.
  export BROWSER="${BROWSER:-$(_first_cmd google-chrome google-chrome-stable firefox chromium)}"
  export TERMINAL="${TERMINAL:-$(_first_cmd kitty ghostty foot)}"
fi

unfunction _first_cmd

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.local/share/bun}"
export CARGO_HOME="${CARGO_HOME:-$HOME/.local/share/cargo}"
export GOPATH="${GOPATH:-$HOME/.local/share/go}"
export NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
export ZSH="${ZSH:-$HOME/.local/share/oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
export PM2_HOME="${PM2_HOME:-$HOME/.local/share/pm2}"
export npm_config_prefix="${npm_config_prefix:-$HOME/.local/share/npm}"
export npm_config_cache="${npm_config_cache:-$HOME/.cache/npm}"
export OLLAMA_HOME="${OLLAMA_HOME:-$HOME/.local/share/ollama}"
export DOTNET_CLI_HOME="${DOTNET_CLI_HOME:-$HOME/.local/share/dotnet}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$HOME/.local/share/android}"
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"

if [[ "$(uname)" == "Darwin" ]]; then
  export HOSTMACHINE="${HOSTMACHINE:-discobot}"
  export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
elif [[ -d "$HOME/Android/Sdk" ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
fi