#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/os-detection.sh"
source "${LIB_DIR}/runtime.sh"

log_header "Preparing Environment"

setup_runtime_tools
mkdir -p "${HOME}/gdrive"

if is_macos; then
    if command -v brew >/dev/null 2>&1; then
        nano_include="include \"$(brew --cellar nano)\"/*/share/nano/*.nanorc"
        touch "${HOME}/.nanorc"
        grep -qxF "$nano_include" "${HOME}/.nanorc" || echo "$nano_include" >> "${HOME}/.nanorc"
    fi
fi

if is_linux && [[ -n "${DOTFILES_TIMEZONE:-}" ]]; then
    log_step "Setting timezone to ${DOTFILES_TIMEZONE}"
    sudo timedatectl set-timezone "${DOTFILES_TIMEZONE}"
fi

case "$DETECTED_OS" in
    arch)
        source "${LIB_DIR}/repos/arch.sh"
        setup_arch_repositories
        ;;
    debian|ubuntu)
        source "${LIB_DIR}/repos/debian.sh"
        setup_debian_repositories
        ;;
    fedora)
        source "${LIB_DIR}/repos/fedora.sh"
        setup_fedora_repositories
        ;;
    macos)
        log_substep "No repository setup needed for macOS"
        ;;
    *)
        log_warning "No repository setup implementation for OS: $DETECTED_OS"
        ;;
esac

log_success "Environment preparation complete"

