function ctolabs () {
  mkdir -p ${DOTFILESSRC}/$1 && mv ~/$1$2 ${DOTFILESSRC}/$1$2 && ln -s ${DOTFILESSRC}/$1$2 ~/$1$2
}

backup() {
    local file new n=0
    local fmt='%s.%(%Y%m%d)T_%02d'
    for file; do
        while :; do
            printf -v new "$fmt" "$file" -1 $((++n))
            [[ -e $new ]] || break
        done
        command cp -vp "$file" "$new"
    done
}