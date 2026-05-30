#!/bin/bash

# Minimal system bootstrap for running the profile installer.
# Keep this limited to tools needed before profile package installation starts.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/os-detection.sh"

ensure_homebrew_on_path() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    local brew_path
    brew_path="$(find /opt /home /usr/local -path '*/bin/brew' -type f 2>/dev/null | head -n 1 || true)"
    if [[ -n "$brew_path" ]]; then
        eval "$("$brew_path" shellenv)"
    fi
}

install_homebrew_if_missing() {
    ensure_homebrew_on_path
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    log_step "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ensure_homebrew_on_path
}

bootstrap_system_prerequisites() {
    log_header "Bootstrapping System Prerequisites"

    case "$DETECTED_OS" in
        arch)
            log_step "Installing Arch bootstrap packages"
            sudo pacman -Syu --needed --noconfirm git jq curl zsh
            ;;
        debian|ubuntu)
            log_step "Installing Debian/Ubuntu bootstrap packages"
            sudo apt-get update -qq
            sudo apt-get install -y git jq curl zsh ca-certificates gnupg
            ;;
        fedora)
            log_step "Installing Fedora bootstrap packages"
            sudo dnf install -y git jq curl zsh ca-certificates gnupg2
            ;;
        macos)
            log_step "Checking macOS bootstrap packages"
            if ! command -v git >/dev/null 2>&1; then
                log_warning "git was not found. Install Xcode Command Line Tools if prompted, then rerun this script."
                xcode-select --install 2>/dev/null || true
            fi
            if ! command -v jq >/dev/null 2>&1; then
                install_homebrew_if_missing
                brew install jq
            fi
            ;;
        *)
            log_warning "No bootstrap implementation for OS: $DETECTED_OS"
            ;;
    esac
}
