#!/bin/bash

# Runtime tooling setup shared by profile preparation scripts.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/logging.sh"

ensure_brew_path() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    local brew_path
    brew_path="$(find /opt /home /usr/local -path '*/bin/brew' -type f 2>/dev/null | head -n 1 || true)"
    if [[ -n "$brew_path" ]]; then
        eval "$("$brew_path" shellenv)"
    fi
}

setup_homebrew() {
    ensure_brew_path
    if command -v brew >/dev/null 2>&1; then
        log_substep "Homebrew already installed"
        return 0
    fi

    log_step "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ensure_brew_path
}

setup_fnm() {
    if command -v fnm >/dev/null 2>&1; then
        log_substep "fnm already installed"
        return 0
    fi

    setup_homebrew
    log_step "Installing fnm"
    brew install fnm
}

load_fnm_env() {
    if command -v fnm >/dev/null 2>&1; then
        eval "$(fnm env --shell bash)"
    fi
}

setup_node() {
    local node_version="${1:-22}"

    setup_fnm
    load_fnm_env

    if command -v node >/dev/null 2>&1; then
        log_substep "node already installed"
        return 0
    fi

    log_step "Installing node ${node_version} with fnm"
    fnm install "$node_version"
    fnm default "$node_version"
    fnm use "$node_version"
}

setup_pnpm() {
    if command -v pnpm >/dev/null 2>&1; then
        log_substep "pnpm already installed"
        return 0
    fi

    log_step "Installing pnpm"
    curl -fsSL https://get.pnpm.io/install.sh | sh -
}

setup_runtime_tools() {
    setup_homebrew
    setup_node "${NODE_VERSION:-22}"
    setup_pnpm
}
