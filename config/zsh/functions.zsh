ctolabs() {
  local target="$1$2"

  [[ -n "$1" ]] || return 1
  mkdir -p "$DOTFILESSRC/$1"
  mv "$HOME/$target" "$DOTFILESSRC/$target"
  ln -s "$DOTFILESSRC/$target" "$HOME/$target"
}

backup() {
  local file new n=0
  local fmt='%s.%(%Y%m%d)T_%02d'

  for file in "$@"; do
    while :; do
      printf -v new "$fmt" "$file" -1 $((++n))
      [[ -e "$new" ]] || break
    done
    command cp -vp "$file" "$new"
  done
}