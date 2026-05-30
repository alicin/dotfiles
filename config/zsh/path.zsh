_path_prepend() {
  [[ -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1${PATH:+:$PATH}" ;;
  esac
}

_path_append() {
  [[ -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="${PATH:+$PATH:}$1" ;;
  esac
}

for dir in /usr/bin /bin /usr/sbin /sbin /usr/local/sbin /usr/local/bin; do
  _path_append "$dir"
done

_path_prepend "$HOME/.local/bin"
_path_prepend "$HOME/.local/bin/scripts"
_path_prepend "$DOTFILESSRC/bin"
_path_prepend "$PNPM_HOME"

_path_append "$CARGO_HOME/bin"
_path_append "$BUN_INSTALL/bin"
_path_append "$GOPATH/bin"
_path_append "$npm_config_prefix/bin"
_path_append "$HOME/.ebcli-virtual-env/executables"
_path_append "/home/linuxbrew/.linuxbrew/bin"
_path_append "/home/linuxbrew/.linuxbrew/sbin"
_path_append "$HOME/.rvm/bin"
_path_append "$HOME/.lmstudio/bin"

unfunction _path_prepend _path_append
unset dir