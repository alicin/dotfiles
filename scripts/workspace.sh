#!/bin/bash

# Clone a repo only if the target directory doesn't already exist
clone_if_missing() {
    local repo="$1"
    local dir
    dir="$(basename "$repo" .git)"
    if [[ -d "$dir" ]]; then
        echo "  • Skipping already cloned: $dir"
    else
        git clone "$repo"
    fi
}

mkdir -p "$HOME/labs/src/bunniesinc"
cd "$HOME/labs/src/bunniesinc"

clone_if_missing git@github.com:alicin/expensepeebs.git
clone_if_missing git@github.com:alicin/peach-pocket.git
clone_if_missing git@github.com:alicin/phantom.git

mkdir -p "$HOME/labs/src/bunniesinc/listpop"
cd "$HOME/labs/src/bunniesinc/listpop"
clone_if_missing git@github.com:alicin/guest-list.git
clone_if_missing git@github.com:alicin/listpop-landing.git

mkdir -p "$HOME/labs/src/bunniesinc/agekit.proj"
cd "$HOME/labs/src/bunniesinc/agekit.proj"
clone_if_missing git@github.com:alicin/agekit-control.git
clone_if_missing git@github.com:alicin/goCamOpenSource.git

mkdir -p "$HOME/labs/src/bunniesinc/exchange-rates"
cd "$HOME/labs/src/bunniesinc/exchange-rates"
clone_if_missing git@github.com:alicin/exchange-rates-api.git
clone_if_missing git@github.com:alicin/exchange-rates-landing.git

mkdir -p "$HOME/labs/src/bunniesinc/j4rv15"
cd "$HOME/labs/src/bunniesinc/j4rv15"
clone_if_missing git@github.com:alicin/j4rv15.git

