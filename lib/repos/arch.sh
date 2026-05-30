#!/bin/bash

# Arch repository and base tooling setup.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/logging.sh"

setup_yay() {
    if command -v yay >/dev/null 2>&1; then
        log_substep "yay already installed"
        return 0
    fi

    log_step "Installing yay"
    local build_dir
    build_dir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
    (cd "$build_dir/yay" && makepkg -si --noconfirm)
    rm -rf "$build_dir"
}

setup_pacman_parallel_downloads() {
    if grep -q '^ParallelDownloads' /etc/pacman.conf; then
        log_substep "pacman parallel downloads already enabled"
        return 0
    fi

    log_step "Enabling pacman parallel downloads"
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
}

setup_arch_repositories() {
    log_header "Setting Up Arch Repositories"

    sudo pacman -Syu --needed --noconfirm base-devel fakeroot debugedit flatpak
    setup_yay
    setup_pacman_parallel_downloads
    sudo pacman -Syu --noconfirm

    if command -v yay >/dev/null 2>&1; then
        yay -Syu --noconfirm
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    log_success "Arch repositories configured"
}
